//
//  Copyright (C) 2026 Sergio Melas
//
//  This file is part of WayPlank.
//
//  WayPlank is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  WayPlank is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

namespace Plank
{
	public delegate void ThumbnailReadyCallback (Gdk.Pixbuf? pixbuf);

	/**
	 * Serializes KWin ScreenShot2 captures (max 1 in flight) and coalesces
	 * duplicate window requests to reduce Wayland/GDK flush EAGAIN pressure.
	 *
	 * Cache policy: small LRU (MAX_CACHE_SIZE), edge-clamped pixbufs, 15s TTL
	 * stale-while-revalidate. close_cards uses clear_ui_pending() so pixbufs
	 * survive; remove_cached() is per-window; clear_all() is deep/exit only.
	 */
	public class KWinThumbnailService : GLib.Object
	{
		static KWinThumbnailService? instance = null;

		public static KWinThumbnailService get_default ()
		{
			if (instance == null)
				instance = new KWinThumbnailService ();
			return instance;
		}

		const int MAX_CACHE_SIZE = 4;
		const int MAX_EDGE_PX = 320;
		const uint MIN_CAPTURE_GAP_MS = 90;
		const int64 CACHE_TTL_MS = 15 * 1000;

		/** Emitted after a pixbuf is stored/replaced in cache (incl. silent SWR refresh). */
		public signal void thumbnail_updated (string win_id);

		class CacheEntry
		{
			public Gdk.Pixbuf pixbuf;
			public int64 captured_at_ms;
			public int last_w;
			public int last_h;

			public CacheEntry (Gdk.Pixbuf pix, int w, int h)
			{
				pixbuf = pix;
				captured_at_ms = GLib.get_monotonic_time () / 1000;
				last_w = w;
				last_h = h;
			}

			public bool is_stale ()
			{
				int64 now = GLib.get_monotonic_time () / 1000;
				return (now - captured_at_ms) > CACHE_TTL_MS;
			}
		}

		class QueuedCapture
		{
			public string win_id;
			public int target_w;
			public int target_h;
			public ThumbnailReadyCallback? notify;
			public uint ui_epoch_at_queue;

			public QueuedCapture (string id, int w, int h, uint epoch)
			{
				win_id = id;
				target_w = w;
				target_h = h;
				notify = null;
				ui_epoch_at_queue = epoch;
			}

			public void add_cb (owned ThumbnailReadyCallback cb)
			{
				if (notify == null) {
					notify = (owned) cb;
					return;
				}
				var older = (owned) notify;
				var newer = (owned) cb;
				notify = (pix) => {
					older (pix);
					newer (pix);
				};
			}
		}

		Gee.HashMap<string, CacheEntry> cache;
		Gee.ArrayList<string> cache_order;
		Gee.HashMap<string, QueuedCapture> queued_by_id;
		Gee.ArrayList<string> queue_order;
		bool capture_in_flight = false;
		string? inflight_win_id = null;
		uint generation = 0;
		uint ui_epoch = 0;
		int64 last_capture_end_ms = 0;

		construct
		{
			cache = new Gee.HashMap<string, CacheEntry> ();
			cache_order = new Gee.ArrayList<string> ();
			queued_by_id = new Gee.HashMap<string, QueuedCapture> ();
			queue_order = new Gee.ArrayList<string> ();
		}

		void touch_lru (string win_id)
		{
			cache_order.remove (win_id);
			cache_order.add (win_id);
		}

		void enqueue_silent_refresh (string win_id, int target_w, int target_h)
		{
			clamp_target_size (ref target_w, ref target_h);

			if (inflight_win_id == win_id)
				return;

			if (queued_by_id.has_key (win_id)) {
				var existing = queued_by_id.get (win_id);
				if (target_w > existing.target_w)
					existing.target_w = target_w;
				if (target_h > existing.target_h)
					existing.target_h = target_h;
				return;
			}

			var item = new QueuedCapture (win_id, target_w, target_h, ui_epoch);
			queued_by_id.set (win_id, item);
			queue_order.add (win_id);
			pump_queue ();
		}

		/**
		 * Return cached pixbuf if any. On TTL miss, still returns the stale
		 * image and queues a single-window silent refresh (SWR).
		 */
		public Gdk.Pixbuf? get_cached (string win_id)
		{
			if (!cache.has_key (win_id))
				return null;

			var entry = cache.get (win_id);
			touch_lru (win_id);

			if (entry.is_stale ())
				enqueue_silent_refresh (win_id, entry.last_w, entry.last_h);

			return entry.pixbuf;
		}

		public void remove_cached (string win_id)
		{
			if (cache.has_key (win_id)) {
				cache.unset (win_id);
				cache_order.remove (win_id);
				PlankCompat.malloc_trim ();
			}
		}

		/**
		 * Soft-cancel UI notify callbacks only. Keeps pixbuf cache and lets
		 * in-flight/queued captures finish so the next card open can hit cache.
		 */
		public void clear_ui_pending ()
		{
			ui_epoch++;
			foreach (var item in queued_by_id.values)
				item.notify = null;
		}

		/**
		 * Deep clean: wipe cache + queue. Prefer remove_cached / clear_ui_pending.
		 * Reserved for exit or rare full reset.
		 */
		public void clear_all ()
		{
			generation++;
			ui_epoch++;
			cache.clear ();
			cache_order.clear ();
			queued_by_id.clear ();
			queue_order.clear ();
			PlankCompat.malloc_trim ();
		}

		static void clamp_target_size (ref int target_w, ref int target_h)
		{
			if (target_w <= 0)
				target_w = 1;
			if (target_h <= 0)
				target_h = 1;

			int max_edge = int.max (target_w, target_h);
			if (max_edge > MAX_EDGE_PX) {
				double scale = (double) MAX_EDGE_PX / (double) max_edge;
				target_w = int.max (1, (int) Math.round (target_w * scale));
				target_h = int.max (1, (int) Math.round (target_h * scale));
			}
		}

		public void request_thumbnail (string win_id, int target_w, int target_h, owned ThumbnailReadyCallback cb)
		{
			clamp_target_size (ref target_w, ref target_h);

			if (cache.has_key (win_id)) {
				var entry = cache.get (win_id);
				touch_lru (win_id);
				cb (entry.pixbuf);

				if (entry.is_stale ()) {
					// Stale-while-revalidate: caller already has old image
					enqueue_silent_refresh (win_id, target_w, target_h);
				} else {
					// Fresh hit — remember latest requested size for future SWR
					entry.last_w = target_w;
					entry.last_h = target_h;
				}
				return;
			}

			// Coalesce: same window already queued — attach callback, bump size if needed
			if (queued_by_id.has_key (win_id)) {
				var existing = queued_by_id.get (win_id);
				existing.add_cb ((owned) cb);
				existing.ui_epoch_at_queue = ui_epoch;
				if (target_w > existing.target_w)
					existing.target_w = target_w;
				if (target_h > existing.target_h)
					existing.target_h = target_h;
				return;
			}

			var item = new QueuedCapture (win_id, target_w, target_h, ui_epoch);
			item.add_cb ((owned) cb);
			queued_by_id.set (win_id, item);
			queue_order.add (win_id);
			pump_queue ();
		}

		void pump_queue ()
		{
			if (capture_in_flight)
				return;
			if (queue_order.size == 0)
				return;

			int64 now = GLib.get_monotonic_time () / 1000;
			int64 elapsed = now - last_capture_end_ms;
			if (last_capture_end_ms > 0 && elapsed < (int64) MIN_CAPTURE_GAP_MS) {
				uint wait = (uint) ((int64) MIN_CAPTURE_GAP_MS - elapsed);
				Timeout.add (wait, () => {
					pump_queue ();
					return false;
				});
				return;
			}

			string win_id = queue_order.remove_at (0);
			var item = queued_by_id.get (win_id);
			if (item == null)
				return;
			queued_by_id.unset (win_id);

			capture_in_flight = true;
			inflight_win_id = win_id;
			uint gen = generation;
			uint epoch = item.ui_epoch_at_queue;
			int req_w = item.target_w;
			int req_h = item.target_h;
			string id_copy = item.win_id;
			ThumbnailReadyCallback? notify = (owned) item.notify;

			Worker.get_default ().add_task (() => {
				Gdk.Pixbuf? pix = capture_window_raw (id_copy, req_w, req_h);

				Idle.add (() => {
					capture_in_flight = false;
					inflight_win_id = null;
					last_capture_end_ms = GLib.get_monotonic_time () / 1000;

					if (gen != generation) {
						// clear_all() happened — drop result, continue queue for new generation
						pump_queue ();
						return false;
					}

					if (pix != null) {
						if (cache.has_key (id_copy)) {
							cache_order.remove (id_copy);
						} else if (cache_order.size >= MAX_CACHE_SIZE) {
							var oldest = cache_order.remove_at (0);
							cache.unset (oldest);
						}
						cache_order.add (id_copy);
						cache.set (id_copy, new CacheEntry (pix, req_w, req_h));
						thumbnail_updated (id_copy);
					}

					// Soft UI cancel: keep cache, skip stale callbacks
					if (notify != null && epoch == ui_epoch)
						notify (pix);

					PlankCompat.malloc_trim ();
					pump_queue ();
					return false;
				});

				return null;
			}, TaskPriority.LOW);
		}

		static Gdk.Pixbuf? capture_window_raw (string win_id, int target_w, int target_h)
		{
			return capture_window_kwin (win_id, target_w, target_h);
		}

		static Gdk.Pixbuf? capture_window_kwin (string win_id, int target_w, int target_h)
		{
			try {
				int pipefd[2];
				if (Posix.pipe (pipefd) != 0) {
					warning ("KWinThumbnailService: pipe() failed: %s", Posix.strerror (Posix.errno));
					return null;
				}

				var fd_list = new UnixFDList ();
				int fd_idx = fd_list.append (pipefd[1]);
				Posix.close (pipefd[1]);

				var conn = Bus.get_sync (BusType.SESSION);
				var builder = new VariantBuilder (new VariantType ("a{sv}"));
				builder.add ("{sv}", "native-resolution", new Variant.boolean (false));

				string method = "CaptureWindow";
				Variant @params;
				if (win_id == "active") {
					method = "CaptureActiveWindow";
					@params = new Variant ("(@a{sv}h)", builder.end (), fd_idx);
				} else {
					@params = new Variant ("(s@a{sv}h)", win_id, builder.end (), fd_idx);
				}

				var msg = new DBusMessage.method_call (
					"org.kde.KWin",
					"/org/kde/KWin/ScreenShot2",
					"org.kde.KWin.ScreenShot2",
					method
				);
				msg.set_body (@params);
				msg.set_unix_fd_list (fd_list);

				var reply = conn.send_message_with_reply_sync (msg, DBusSendMessageFlags.NONE, 2500, null);
				if (reply == null) {
					warning ("KWinThumbnailService: D-Bus reply NULL for '%s'", win_id);
					Posix.close (pipefd[0]);
					return null;
				}
				if (reply.get_message_type () == DBusMessageType.ERROR) {
					Logger.verbose ("KWinThumbnailService: D-Bus ERROR for '%s': %s",
						win_id, reply.get_error_name ());
					Posix.close (pipefd[0]);
					return null;
				}

				var body = reply.get_body ();
				Variant map = body.get_child_value (0);

				uint32 width = 0, height = 0, stride = 0;
				map.lookup ("width", "u", out width);
				map.lookup ("height", "u", out height);
				map.lookup ("stride", "u", out stride);

				Logger.verbose ("KWinThumbnailService: %ux%u stride=%u target=%dx%d",
					width, height, stride, target_w, target_h);

				if (width == 0 || height == 0 || stride == 0) {
					Posix.close (pipefd[0]);
					return null;
				}

				size_t total_bytes = (size_t) height * stride;
				uint8[] buffer = new uint8[total_bytes];
				size_t read_bytes = 0;
				while (read_bytes < total_bytes) {
					Posix.pollfd pfd[1];
					pfd[0].fd = pipefd[0];
					pfd[0].events = Posix.POLLIN;
					pfd[0].revents = 0;
					int pr = Posix.poll (pfd, 500);
					if (pr <= 0)
						break;
					ssize_t n = Posix.read (pipefd[0], (uint8*) buffer + read_bytes, total_bytes - read_bytes);
					if (n <= 0) break;
					read_bytes += n;
				}
				Posix.close (pipefd[0]);

				if (read_bytes < total_bytes)
					return null;

				/* BGRA -> RGBA in place */
				for (size_t i = 0; i < total_bytes; i += 4) {
					uint8 b = buffer[i];
					buffer[i] = buffer[i + 2];
					buffer[i + 2] = b;
					buffer[i + 3] = 255;
				}

				int out_w = target_w;
				int out_h = target_h;
				clamp_target_size (ref out_w, ref out_h);

				/* Box-downsample into a small owning buffer, then free the
				 * full-resolution ScreenShot2 mmap immediately. Never keep a
				 * full-res Gdk.Pixbuf around (was a major RSS spike source). */
				int small_stride = out_w * 4;
				uint8[] small = new uint8[small_stride * out_h];
				for (int dy = 0; dy < out_h; dy++) {
					int sy0 = (int) ((int64) dy * (int64) height / out_h);
					int sy1 = (int) ((int64) (dy + 1) * (int64) height / out_h);
					if (sy1 <= sy0) sy1 = sy0 + 1;
					if (sy1 > (int) height) sy1 = (int) height;
					for (int dx = 0; dx < out_w; dx++) {
						int sx0 = (int) ((int64) dx * (int64) width / out_w);
						int sx1 = (int) ((int64) (dx + 1) * (int64) width / out_w);
						if (sx1 <= sx0) sx1 = sx0 + 1;
						if (sx1 > (int) width) sx1 = (int) width;
						uint32 sum_r = 0, sum_g = 0, sum_b = 0, count = 0;
						for (int sy = sy0; sy < sy1; sy++) {
							size_t row = (size_t) sy * stride;
							for (int sx = sx0; sx < sx1; sx++) {
								size_t off = row + (size_t) sx * 4;
								sum_r += buffer[off];
								sum_g += buffer[off + 1];
								sum_b += buffer[off + 2];
								count++;
							}
						}
						if (count == 0) count = 1;
						int dst = dy * small_stride + dx * 4;
						small[dst] = (uint8) (sum_r / count);
						small[dst + 1] = (uint8) (sum_g / count);
						small[dst + 2] = (uint8) (sum_b / count);
						small[dst + 3] = 255;
					}
				}
				buffer = {};
				PlankCompat.malloc_trim ();

				var scaled = new Gdk.Pixbuf.from_data (
					small,
					Gdk.Colorspace.RGB,
					true,
					8,
					out_w,
					out_h,
					small_stride,
					null
				);
				/* Detach: copy into an owning pixbuf so `small` can be dropped. */
				Gdk.Pixbuf? owned = (scaled != null) ? scaled.copy () : null;
				scaled = null;
				small = {};
				PlankCompat.malloc_trim ();
				return owned;
			} catch (Error e) {
				return null;
			}
		}
	}
}
