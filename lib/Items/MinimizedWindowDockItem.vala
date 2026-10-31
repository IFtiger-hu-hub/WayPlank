//
//  Copyright (C) 2026 史有虎 (IFtiger-hu)
//
//  This file is part of kde-dockbar.
//
//  kde-dockbar is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  kde-dockbar is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

namespace Plank
{
	/**
	 * A dock item representing a minimized application window, anchored in an
	 * independent category right next to the Trash. Default glyph is the app icon;
	 * a live ScreenShot2 thumbnail is fetched only on hover and kept in a small LRU.
	 */
	public class MinimizedWindowDockItem : DockItem
	{
		public string WindowId { get; construct set; }
		public string Caption { get; set; default = ""; }
		public string LauncherUri { get; set; default = ""; }
		public string AppIconName { get; set; default = ""; }
		/** Gates duplicate in-flight ScreenShot2 requests from hover. */
		bool thumbnail_requested = false;

		public MinimizedWindowDockItem (string window_id, string caption, string icon_name, string launcher_uri)
		{
			GLib.Object (
				Prefs: new DockItemPreferences (),
				WindowId: window_id
			);

			this.Caption = caption;
			this.AppIconName = (icon_name.length > 0) ? icon_name : "application-default-icon";
			this.LauncherUri = launcher_uri;
			this.Icon = this.AppIconName;
			this.Text = (caption.length > 0) ? caption : "已最小化窗口";
			this.Button = PopupButton.LEFT;
			KWinThumbnailService.get_default ().thumbnail_updated.connect (on_thumbnail_updated);
		}

		~MinimizedWindowDockItem ()
		{
			KWinThumbnailService.get_default ().thumbnail_updated.disconnect (on_thumbnail_updated);
			KWinThumbnailService.get_default ().remove_cached (WindowId);
			reset_icon_buffer ();
		}

		void on_thumbnail_updated (string win_id)
		{
			if (win_id == WindowId) {
				reset_icon_buffer ();
				needs_redraw ();
			}
		}

		public override bool is_valid ()
		{
			return true;
		}

		public override bool can_be_removed ()
		{
			return false;
		}

		public void update_caption (string new_caption)
		{
			if (this.Caption != new_caption) {
				this.Caption = new_caption;
				this.Text = (new_caption.length > 0) ? new_caption : "已最小化窗口";
				reset_icon_buffer ();
				needs_redraw ();
			}
		}

		/**
		 * Lazy live thumb: ScreenShot2 only on hover (joins KWinThumbnailService
		 * small LRU). Create/draw never burst-captures every minimized icon.
		 */
		protected override AnimationType on_hovered ()
		{
			ensure_live_thumbnail ();
			return AnimationType.NONE;
		}

		void ensure_live_thumbnail ()
		{
			// Already in live-thumb LRU: touch for SWR; icon surface already has thumb.
			if (KWinThumbnailService.get_default ().get_cached (WindowId) != null)
				return;

			if (thumbnail_requested)
				return;

			int size = 64;
			unowned DockController? dock = get_dock ();
			if (dock != null && dock.position_manager.IconSize > 0)
				size = dock.position_manager.IconSize;

			thumbnail_requested = true;
			string id_copy = WindowId;
			KWinThumbnailService.get_default ().request_thumbnail (id_copy, size, size, (pix) => {
				thumbnail_requested = false;
				if (pix != null) {
					reset_icon_buffer ();
					needs_redraw ();
				}
			});
		}

		public void restore_window ()
		{
			unowned DockController? dock = get_dock ();
			if (dock != null)
				dock.sync_minimized_geometries ();
			WindowControl.queue_command (WindowId, "activate");
		}

		public void close_window ()
		{
			WindowControl.queue_command (WindowId, "close");
		}

		protected override AnimationType on_clicked (PopupButton button, Gdk.ModifierType mod, uint32 event_time)
		{
			if (button == PopupButton.LEFT) {
				restore_window ();
				return AnimationType.BOUNCE;
			} else if (button == PopupButton.MIDDLE) {
				close_window ();
				return AnimationType.NONE;
			}

			return AnimationType.NONE;
		}

		protected override void draw_icon (Surface surface)
		{
			unowned Cairo.Context cr = surface.Context;
			double w = surface.Width;
			double h = surface.Height;
			if (w <= 0 || h <= 0)
				return;

			/* Cheap default = app-icon capsule. Live ScreenShot2 thumb only if this
			 * window is in the small LRU live-thumb cache (hover / recent hover).
			 * Never request captures from draw — that used to burst N ScreenShot2
			 * calls whenever many windows were minimized. */
			Gdk.Pixbuf? thumb = KWinThumbnailService.get_default ().get_cached (WindowId);

			double pad = 3.0;
			double card_x = pad;
			double card_y = pad;
			double card_w = w - pad * 2.0;
			double card_h = h - pad * 2.0;
			double card_r = 5.0;

			if (thumb != null) {
				// Base card background
				Theme.draw_rounded_rect (cr, card_x, card_y, card_w, card_h, card_r, card_r, 0.0);
				cr.set_source_rgba (0.12, 0.14, 0.18, 0.85);
				cr.fill ();

				// Aspect-ratio scaled thumbnail centered inside card
				var scaled = DrawingService.ar_scale (thumb, (int) card_w, (int) card_h);
				if (scaled != null) {
					double ix = card_x + (card_w - scaled.width) / 2.0;
					double iy = card_y + (card_h - scaled.height) / 2.0;

					cr.save ();
					Theme.draw_rounded_rect (cr, card_x, card_y, card_w, card_h, card_r, card_r, 0.0);
					cr.clip ();
					Gdk.cairo_set_source_pixbuf (cr, scaled, ix, iy);
					cr.paint ();
					cr.restore ();
				}

				// Outer glass stroke
				Theme.draw_rounded_rect (cr, card_x, card_y, card_w, card_h, card_r, card_r, 0.0);
				cr.set_source_rgba (1.0, 1.0, 1.0, 0.28);
				cr.set_line_width (1.0);
				cr.stroke ();

				// Bottom-right application icon badge
				int badge_size = (int) (w * 0.36);
				badge_size = badge_size.clamp (14, 24);
				double bx = w - badge_size - 1.0;
				double by = h - badge_size - 1.0;

				cr.arc (bx + badge_size / 2.0, by + badge_size / 2.0, badge_size / 2.0 + 1.5, 0, 2 * Math.PI);
				cr.set_source_rgba (0.08, 0.10, 0.14, 0.96);
				cr.fill_preserve ();
				cr.set_source_rgba (1.0, 1.0, 1.0, 0.3);
				cr.set_line_width (1.0);
				cr.stroke ();

				double x_scale = 1.0, y_scale = 1.0;
				surface.Internal.get_device_scale (out x_scale, out y_scale);
				var badge_surface = DrawingService.load_icon_for_scale (AppIconName, badge_size, badge_size, (int) double.max (x_scale, y_scale));
				if (badge_surface != null) {
					badge_surface.set_device_scale (1.0, 1.0);
					cr.set_source_surface (badge_surface, bx, by);
					cr.paint ();
				}
			} else {
				// Sleek fallback preview window capsule
				Theme.draw_rounded_rect (cr, card_x, card_y, card_w, card_h, card_r, card_r, 0.0);
				cr.set_source_rgba (0.15, 0.18, 0.24, 0.92);
				cr.fill ();

				// Mini window header strip
				cr.save ();
				Theme.draw_rounded_rect (cr, card_x, card_y, card_w, card_h, card_r, card_r, 0.0);
				cr.clip ();
				cr.rectangle (card_x, card_y, card_w, 7.0);
				cr.set_source_rgba (0.24, 0.28, 0.36, 0.95);
				cr.fill ();

				// Window dots
				cr.arc (card_x + 5.0, card_y + 3.5, 1.4, 0, 2 * Math.PI);
				cr.set_source_rgba (1.0, 0.42, 0.42, 0.9);
				cr.fill ();
				cr.arc (card_x + 9.5, card_y + 3.5, 1.4, 0, 2 * Math.PI);
				cr.set_source_rgba (1.0, 0.78, 0.32, 0.9);
				cr.fill ();
				cr.arc (card_x + 14.0, card_y + 3.5, 1.4, 0, 2 * Math.PI);
				cr.set_source_rgba (0.38, 0.88, 0.45, 0.9);
				cr.fill ();
				cr.restore ();

				// App icon in center of card
				int icon_size = (int) (w * 0.46);
				icon_size = icon_size.clamp (16, 48);
				double x_scale = 1.0, y_scale = 1.0;
				surface.Internal.get_device_scale (out x_scale, out y_scale);
				var center_surface = DrawingService.load_icon_for_scale (AppIconName, icon_size, icon_size, (int) double.max (x_scale, y_scale));
				if (center_surface != null) {
					center_surface.set_device_scale (1.0, 1.0);
					cr.set_source_surface (center_surface, card_x + (card_w - icon_size) / 2.0, card_y + 7.0 + (card_h - 7.0 - icon_size) / 2.0);
					cr.paint ();
				}

				// Outer glass stroke
				Theme.draw_rounded_rect (cr, card_x, card_y, card_w, card_h, card_r, card_r, 0.0);
				cr.set_source_rgba (1.0, 1.0, 1.0, 0.22);
				cr.set_line_width (1.0);
				cr.stroke ();
			}
		}

		public override Gee.ArrayList<Gtk.MenuItem> get_menu_items ()
		{
			var items = new Gee.ArrayList<Gtk.MenuItem> ();

			var header = new Gtk.MenuItem ();
			var label = new Gtk.Label ("");
			string clean_title = (Caption.length > 0) ? Caption : "已最小化窗口";
			if (clean_title.length > 28)
				clean_title = clean_title.substring (0, 25) + "...";
			label.set_markup ("<b>%s</b>".printf (Markup.escape_text (clean_title)));
			label.set_xalign (0.0f);
			header.add (label);
			header.sensitive = false;
			items.add (header);

			items.add (new Gtk.SeparatorMenuItem ());

			var restore_item = create_menu_item ("恢复窗口(_R)", "view-restore", true);
			restore_item.activate.connect (restore_window);
			items.add (restore_item);

			var close_item = create_menu_item ("关闭窗口(_C)", "window-close", true);
			close_item.activate.connect (close_window);
			items.add (close_item);

			return items;
		}
	}
}

