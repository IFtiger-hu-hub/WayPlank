//
//  Copyright (C) 2011-2012 Robert Dyer, Michal Hruby, Rico Tzschichholz
//  Copyright (C) 2026 Sergio Melas
//
//  This file is part of Wayplank.
//
//  Wayplank is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Wayplank is distributed in the hope that it will be useful,
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
	 * A dock item for applications (with .desktop launchers).
	 */
	public class ApplicationDockItem : DockItem
	{
		// for FDO Desktop Actions
		// see http://standards.freedesktop.org/desktop-entry-spec/desktop-entry-spec-latest.html#extra-actions
		private const string DESKTOP_ACTION_KEY = "Actions";
		private const string DESKTOP_ACTION_GROUP_NAME = "Desktop Action %s";
		
		// for the Unity static quicklists
		// see https://wiki.edubuntu.org/Unity/LauncherAPI#Static_Quicklist_entries
		private const string UNITY_QUICKLISTS_KEY = "X-Ayatana-Desktop-Shortcuts";
		private const string UNITY_QUICKLISTS_SHORTCUT_GROUP_NAME = "%s Shortcut Group";
		private const string UNITY_QUICKLISTS_TARGET_KEY = "TargetEnvironment";
		private const string UNITY_QUICKLISTS_TARGET_VALUE = "Unity";
		
		private const string[] SUPPORTED_GETTEXT_DOMAINS_KEYS = {"X-Ubuntu-Gettext-Domain", "X-GNOME-Gettext-Domain"};
		
		/**
		 * Signal fired when the item's 'keep in dock' menu item is pressed.
		 */
		public signal void pin_launcher ();
		
#if HAVE_DBUSMENU
		/**
		 * The dock item's quicklist-dbusmenu.
		 */
		DbusmenuGtk.Client? Quicklist { get; set; default = null; }
#endif
		
		Gee.ArrayList<string> supported_mime_types = new Gee.ArrayList<string> ();
		Gee.ArrayList<string> actions = new Gee.ArrayList<string> ();
		Gee.HashMap<string, string> actions_map = new Gee.HashMap<string, string> ();
		Gee.HashMap<string, string> desktop_action_ids = new Gee.HashMap<string, string> ();
		public bool accepts_payload { get; private set; default = false; }
		
		public bool can_accept_any_drop ()
		{
			return (accepts_payload || (supported_mime_types != null && supported_mime_types.size > 0));
		}
		
		string? unity_dbusname = null;
		int prev_window_count = 0;

		public static unowned ApplicationDockItem? current_expanded_item = null;
		public static int64 cards_animating_until = 0LL;
		public static int total_collapsing_cards = 0;
		Gee.ArrayList<WindowCardDockItem> expanded_cards = new Gee.ArrayList<WindowCardDockItem> ();
		Gee.ArrayList<WindowCardDockItem> collapsing_cards = new Gee.ArrayList<WindowCardDockItem> ();
		uint collapse_timer_id = 0;
		bool is_expanded = false;

		public static bool is_animating_cards ()
		{
			var now = GLib.get_monotonic_time ();
			if (now < cards_animating_until)
				return true;
			if (total_collapsing_cards > 0)
				return true;
			return false;
		}

		public static void collapse_all_cards ()
		{
			if (current_expanded_item != null) {
				current_expanded_item.collapse_cards ();
			}
		}

		public void collapse_cards ()
		{
			if (!is_expanded && expanded_cards.size == 0)
				return;

			is_expanded = false;
			if (current_expanded_item == this)
				current_expanded_item = null;

			var now = GLib.get_monotonic_time ();
			cards_animating_until = now + 300 * 1000;

			foreach (var card in expanded_cards) {
				card.RemoveTime = now;
				collapsing_cards.add (card);
				total_collapsing_cards++;
			}
			expanded_cards.clear ();
			get_dock ()?.renderer.animated_draw ();

			// After the smoothstep shrink animation finishes (250ms), remove cards cleanly from container in a single batch
			if (collapse_timer_id == 0) {
				collapse_timer_id = GLib.Timeout.add (270, () => {
					collapse_timer_id = 0;
					unowned DockContainer? container = Container;
					if (container != null && collapsing_cards.size > 0) {
						var finished = new Gee.ArrayList<DockElement> ();
						foreach (var card in collapsing_cards) {
							finished.add (card);
						}
						container.remove_batch (finished);
						total_collapsing_cards -= finished.size;
						if (total_collapsing_cards < 0)
							total_collapsing_cards = 0;
						collapsing_cards.clear ();
						(container as DefaultApplicationDockItemProvider)?.refresh_separators ();
					} else {
						total_collapsing_cards -= collapsing_cards.size;
						if (total_collapsing_cards < 0)
							total_collapsing_cards = 0;
						collapsing_cards.clear ();
					}
					return GLib.Source.REMOVE;
				});
			}
		}

		public void expand_cards ()
		{
			if (is_expanded)
				return;

			collapse_all_cards ();

			if (collapse_timer_id > 0) {
				GLib.Source.remove (collapse_timer_id);
				collapse_timer_id = 0;
				unowned DockContainer? c = Container;
				if (c != null && collapsing_cards.size > 0) {
					var to_remove = new Gee.ArrayList<DockElement> ();
					foreach (var card in collapsing_cards)
						to_remove.add (card);
					c.remove_batch (to_remove);
				}
				total_collapsing_cards -= collapsing_cards.size;
				if (total_collapsing_cards < 0)
					total_collapsing_cards = 0;
				collapsing_cards.clear ();
			}

			unowned DefaultApplicationDockItemProvider? provider = (Container as DefaultApplicationDockItemProvider);
			if (provider == null)
				return;

			var windows = WindowManager.get_default ().matching_windows (Launcher);
			var current_desktop_only = provider.Prefs.CurrentWorkspaceOnly;
			var candidates = new Gee.ArrayList<WindowInfo> ();
			foreach (var win in windows) {
				if (!current_desktop_only || win.CurrentDesktop) {
					candidates.add (win);
				}
			}

			if (candidates.size <= 1)
				return;

			current_expanded_item = this;
			is_expanded = true;

			var now = GLib.get_monotonic_time ();
			cards_animating_until = now + 300 * 1000;

			var new_cards = new Gee.ArrayList<DockElement> ();
			foreach (var win in candidates) {
				var sub_caption = clean_window_caption (win.Caption, Text);
				var card = new WindowCardDockItem (win.Id, Text, win.Output, sub_caption, Icon, this);
				card.AddTime = now;
				new_cards.add (card);
				expanded_cards.add (card);
			}

			provider.insert_batch_after (new_cards, this);
			if (new_cards.size > 0) {
				get_dock ()?.position_manager.ensure_item_visible (new_cards.last () as DockItem);
			}
			get_dock ()?.renderer.animated_draw ();
		}

		static string clean_window_caption (string caption, string app_text)
		{
			var trimmed = caption.strip ();
			if (trimmed.length == 0)
				return app_text;

			var suffixes = new string[] {
				" — " + app_text,
				" - " + app_text,
				" — " + app_text.down (),
				" - " + app_text.down ()
			};
			foreach (var suffix in suffixes) {
				if (trimmed.has_suffix (suffix)) {
					var sub = trimmed.substring (0, trimmed.length - suffix.length).strip ();
					if (sub.length > 0)
						return sub;
				}
			}
			return trimmed;
		}
		
		/**
		 * {@inheritDoc}
		 */
		public ApplicationDockItem.with_dockitem_file (GLib.File file)
		{
			GLib.Object (Prefs: new DockItemPreferences.with_file (file));
		}
		
		/**
		 * {@inheritDoc}
		 */
		public ApplicationDockItem.with_dockitem_filename (string filename)
		{
			GLib.Object (Prefs: new DockItemPreferences.with_filename (filename));
		}
		
		construct
		{
			supported_mime_types = new Gee.ArrayList<string> ();
			actions = new Gee.ArrayList<string> ();
			actions_map = new Gee.HashMap<string, string> ();
			desktop_action_ids = new Gee.HashMap<string, string> ();
			Matcher.get_default ().processes_changed.connect (handle_processes_changed);
			WindowManager.get_default ().windows_refreshed.connect (handle_window_state_changed);
			
			load_from_launcher ();
			prev_window_count = WindowManager.get_default ().window_count_for_app (Launcher);
			update_indicator (!WindowControl.has_state ());
		}
		
		~ApplicationDockItem ()
		{
			if (collapse_timer_id > 0) {
				GLib.Source.remove (collapse_timer_id);
				collapse_timer_id = 0;
			}
			unowned DockContainer? c = Container;
			if (c != null) {
				var to_remove = new Gee.ArrayList<DockElement> ();
				foreach (var card in expanded_cards)
					to_remove.add (card);
				foreach (var card in collapsing_cards)
					to_remove.add (card);
				if (to_remove.size > 0)
					c.remove_batch (to_remove);
			}
			total_collapsing_cards -= collapsing_cards.size;
			if (total_collapsing_cards < 0)
				total_collapsing_cards = 0;
			expanded_cards.clear ();
			collapsing_cards.clear ();
			supported_mime_types = null;
			actions = null;
			actions_map = null;
			desktop_action_ids = null;
			
			Matcher.get_default ().processes_changed.disconnect (handle_processes_changed);
			WindowManager.get_default ().windows_refreshed.disconnect (handle_window_state_changed);
#if HAVE_DBUSMENU
			Quicklist = null;
#endif
		}
		
		public bool is_running ()
		{
			return Matcher.get_default ().is_launcher_running (Launcher);
		}
		
		public bool is_window ()
		{
			return false;
		}

		void handle_processes_changed ()
		{
			update_indicator (true);
		}

		void handle_window_state_changed ()
		{
			update_indicator (false);
			if (is_expanded) {
				var windows = WindowManager.get_default ().matching_windows (Launcher);
				if (windows.size <= 1) {
					collapse_cards ();
				}
			}
		}

		public void set_urgent (bool is_urgent)
		{
			var was_urgent = (State & ItemState.URGENT) != 0;
			if (is_urgent) {
				if (!was_urgent)
					LastUrgent = GLib.get_monotonic_time ();
				State |= ItemState.URGENT;
			} else {
				State &= ~ItemState.URGENT;
			}
		}
		
		protected void update_indicator (bool scan_process)
		{
			unowned DefaultApplicationDockItemProvider? provider = (Container as DefaultApplicationDockItemProvider);
			var show_running = (provider == null || provider.Prefs.ShowRunningIndicators);
			var show_attention = (provider == null || provider.Prefs.ShowAttentionIndicators);
			var window_manager = WindowManager.get_default ();
			var window_count = window_manager.window_count_for_app (Launcher);
			var running = (window_count > 0 || (scan_process && is_running ()));
			
			var had_open_windows = (prev_window_count > 0);
			prev_window_count = window_count;
			
			if (!show_running || !running)
				Indicator = IndicatorState.NONE;
			else
				Indicator = (window_count > 1 ? IndicatorState.SINGLE_PLUS : IndicatorState.SINGLE);
			
			if (show_attention && window_manager.app_demands_attention (Launcher))
				set_urgent (true);
			else if ((State & ItemState.URGENT) != 0)
				set_urgent (false);
			
			// Only bounce if THIS specific app had open windows and its last window was closed
			if (had_open_windows && window_count == 0) {
				ClickedAnimation = AnimationType.BOUNCE;
				LastClicked = GLib.get_monotonic_time ();
			}
		}
		
		void launch ()
		{
			System.get_default ().launch (File.new_for_uri (Prefs.Launcher));
		}
		
		/**
		 * {@inheritDoc}
		 */
		protected override AnimationType on_clicked (PopupButton button, Gdk.ModifierType mod, uint32 event_time)
		{
			if (button == PopupButton.MIDDLE
				|| (button == PopupButton.LEFT && (mod & Gdk.ModifierType.CONTROL_MASK) != 0)) {
					message ("Wayplank: click on '%s' -> launching new instance (is_running=%s)", Text, is_running ().to_string ());
					launch ();
					return AnimationType.BOUNCE;
				}
			
			if (button == PopupButton.LEFT) {
				var app_id = File.new_for_uri (Launcher).get_basename ();
				unowned DefaultApplicationDockItemProvider? provider = (Container as DefaultApplicationDockItemProvider);
				var click_behavior = (provider != null ? provider.Prefs.WindowClickBehavior : 0);
				var restore_minimized = (provider == null || provider.Prefs.RestoreMinimizedWindows);

				// If this application is already expanded, clicking it toggles collapse
				if (is_expanded) {
					collapse_cards ();
					return AnimationType.NONE;
				}

				// If any other application was expanded, collapse it first
				collapse_all_cards ();

				var windows = WindowManager.get_default ().matching_windows (Launcher);
				var current_desktop_only = (provider != null && provider.Prefs.CurrentWorkspaceOnly);
				var candidates = new Gee.ArrayList<WindowInfo> ();
				foreach (var win in windows) {
					if (!current_desktop_only || win.CurrentDesktop) {
						candidates.add (win);
					}
				}

				// Mode 2: Expand/collapse window cards beside dock icon
				if (click_behavior == 2 && candidates.size > 1) {
					if (is_expanded)
						collapse_cards ();
					else
						expand_cards ();
					return AnimationType.NONE;
				}

				// Mode 1: Present Windows (KWin large previews)
				if (click_behavior == 1 && candidates.size > 1) {
					var uuids = new Gee.ArrayList<string> ();
					foreach (var win in candidates) {
						uuids.add (win.Id);
					}
					if (WindowControl.present_windows (uuids)) {
						message ("Wayplank: click on '%s' -> present windows (%d)", Text, uuids.size);
						return AnimationType.BOUNCE;
					}
				}

				// Mode 0 (Default): Indicators & Cycle / Activate window
				string? uuid;
				string action;
				if (WindowManager.get_default ().resolve_click_command (Launcher, 0, restore_minimized, out uuid, out action)) {
					message ("Wayplank: click on '%s' (app_id=%s) -> uuid=%s action=%s", Text, app_id, uuid, action);
					WindowControl.queue_command (uuid, action);
					return AnimationType.BOUNCE;
				}
				message ("Wayplank: click on '%s' -> no matching window, launching new instance", Text);
				launch ();
				return AnimationType.BOUNCE;
			}
			
			return AnimationType.NONE;
		}
		
		/**
		 * {@inheritDoc}
		 */
		protected override AnimationType on_scrolled (Gdk.ScrollDirection direction, Gdk.ModifierType mod, uint32 event_time)
		{
			base.on_scrolled (direction, mod, event_time);
			bool forward = (direction == Gdk.ScrollDirection.UP || direction == Gdk.ScrollDirection.RIGHT);
			string? uuid;
			if (WindowManager.get_default ().cycle_window (Launcher, forward, out uuid)) {
				message ("Wayplank: scroll on '%s' -> cycle window uuid=%s (forward=%s)", Text, uuid, forward.to_string ());
				WindowControl.queue_command (uuid, "activate");
			}
			return AnimationType.NONE;
		}
		
		/**
		 * {@inheritDoc}
		 */
		void launch_target_path (string path)
		{
			try {
				var file = File.new_for_path (path);
				var uri = file.get_uri ();
				List<string> uris = new List<string> ();
				uris.append (uri);

				var desktop_path = File.new_for_uri (Launcher).get_path ();
				if (desktop_path != null) {
					var app_info = new DesktopAppInfo.from_filename (desktop_path);
					if (app_info != null) {
						app_info.launch_uris (uris, System.get_default ().context);
						return;
					}
				}

				AppInfo.launch_default_for_uri (uri, null);
			} catch (Error e) {
				Logger.notification ("Failed to launch recent path: %s", e.message);
			}
		}

		static inline string get_dim_color ()
		{
			return SystemTheme.get_default ().is_dark ? "#94a3b8" : "#64748b";
		}

		Gtk.MenuItem create_header_menu_item (int win_count)
		{
			var item = new Gtk.MenuItem ();
			item.sensitive = false;
			item.can_focus = false;

			var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
			hbox.margin_top = 8;
			hbox.margin_bottom = 8;
			hbox.margin_start = 10;
			hbox.margin_end = 10;

			// Icon (36x36)
			var pixbuf = DrawingService.load_icon (Icon, 36, 36);
			if (pixbuf != null) {
				var img = new Gtk.Image.from_pixbuf (pixbuf);
				hbox.pack_start (img, false, false, 0);
			} else {
				var img = new Gtk.Image.from_icon_name ("application-x-executable", Gtk.IconSize.DND);
				hbox.pack_start (img, false, false, 0);
			}

			var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 3);
			vbox.valign = Gtk.Align.CENTER;

			var title_lbl = new Gtk.Label (null);
			title_lbl.set_markup ("<b><span size='11500'>%s</span></b>".printf (GLib.Markup.escape_text (Text)));
			title_lbl.halign = Gtk.Align.START;
			title_lbl.ellipsize = Pango.EllipsizeMode.END;
			vbox.pack_start (title_lbl, false, false, 0);

			var status_str = (win_count > 0)
				? (win_count > 1 ? ("运行中 · %d 个窗口".printf (win_count)) : "正在运行")
				: "未运行";

			var status_lbl = new Gtk.Label (null);
			status_lbl.set_markup ("<span size='9500' foreground='%s'>%s</span>".printf (get_dim_color (), status_str));
			status_lbl.halign = Gtk.Align.START;
			vbox.pack_start (status_lbl, false, false, 0);

			hbox.pack_start (vbox, true, true, 0);
			item.add (hbox);
			item.show_all ();
			return item;
		}

		Gtk.MenuItem create_section_header_item (string label_text)
		{
			var item = new Gtk.MenuItem ();
			item.sensitive = false;
			item.can_focus = false;

			var lbl = new Gtk.Label (null);
			lbl.set_markup ("<b><span size='8500' foreground='%s'>%s</span></b>".printf (get_dim_color (), GLib.Markup.escape_text (label_text)));
			lbl.halign = Gtk.Align.START;
			lbl.margin_start = 10;
			lbl.margin_top = 4;
			lbl.margin_bottom = 2;

			item.add (lbl);
			item.show_all ();
			return item;
		}

		Gtk.MenuItem create_recent_file_menu_item (RecentFileInfo rf)
		{
			var item = new Gtk.MenuItem ();

			var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
			hbox.margin_start = 10;
			hbox.margin_end = 10;
			hbox.margin_top = 4;
			hbox.margin_bottom = 4;

			string icon_name = "text-x-generic";
			if (rf.is_dir) {
				icon_name = "folder";
			} else {
				var p = rf.path.down ();
				if (p.has_suffix (".pdf")) icon_name = "application-pdf";
				else if (p.has_suffix (".png") || p.has_suffix (".jpg") || p.has_suffix (".jpeg") || p.has_suffix (".svg") || p.has_suffix (".webp")) icon_name = "image-x-generic";
				else if (p.has_suffix (".md") || p.has_suffix (".txt")) icon_name = "text-plain";
				else if (p.has_suffix (".ts") || p.has_suffix (".js") || p.has_suffix (".json") || p.has_suffix (".qml") || p.has_suffix (".py") || p.has_suffix (".cpp") || p.has_suffix (".c") || p.has_suffix (".h")) icon_name = "text-x-script";
			}

			var pixbuf = DrawingService.load_icon (icon_name, 20, 20);
			if (pixbuf != null) {
				var img = new Gtk.Image.from_pixbuf (pixbuf);
				hbox.pack_start (img, false, false, 0);
			} else {
				var img = new Gtk.Image.from_icon_name (icon_name, Gtk.IconSize.MENU);
				hbox.pack_start (img, false, false, 0);
			}

			var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
			vbox.valign = Gtk.Align.CENTER;

			var title_lbl = new Gtk.Label (null);
			title_lbl.set_markup ("<span size='9800'>%s</span>".printf (GLib.Markup.escape_text (rf.title)));
			title_lbl.halign = Gtk.Align.START;
			title_lbl.ellipsize = Pango.EllipsizeMode.MIDDLE;
			title_lbl.max_width_chars = 34;
			vbox.pack_start (title_lbl, false, false, 0);

			var path_lbl = new Gtk.Label (null);
			path_lbl.set_markup ("<span size='8500' foreground='%s'>%s</span>".printf (get_dim_color (), GLib.Markup.escape_text (rf.display_path)));
			path_lbl.halign = Gtk.Align.START;
			path_lbl.ellipsize = Pango.EllipsizeMode.MIDDLE;
			path_lbl.max_width_chars = 38;
			vbox.pack_start (path_lbl, false, false, 0);

			hbox.pack_start (vbox, true, true, 0);
			item.add (hbox);

			string target_path = rf.path;
			item.activate.connect (() => {
				launch_target_path (target_path);
			});

			item.show_all ();
			return item;
		}

		/**
		 * {@inheritDoc}
		 */
		public override Gee.ArrayList<Gtk.MenuItem> get_menu_items ()
		{
			var items = new Gee.ArrayList<Gtk.MenuItem> ();
			var windows = WindowManager.get_default ().matching_windows (Launcher);

			// 1. App Header (Icon + Name + Status)
			items.add (create_header_menu_item (windows.size));

			// 2. Recent Files / Projects Section
			var recent_files = RecentFilesService.get_default ().get_recent_files (null, Launcher, Text);
			if (recent_files.size > 0) {
				items.add (new Gtk.SeparatorMenuItem ());
				items.add (create_section_header_item ("最近打开"));

				int count = 0;
				foreach (var rf in recent_files) {
					items.add (create_recent_file_menu_item (rf));
					count++;
					if (count >= 8)
						break;
				}
			}

			// 3. Desktop Actions Section
			if (!is_window () && actions.size > 0) {
				items.add (new Gtk.SeparatorMenuItem ());
				items.add (create_section_header_item ("快捷操作"));

				foreach (var s in actions) {
					var values = actions_map.get (s).split (";;");
					var action_id = desktop_action_ids.get (s);

					var item = create_menu_item (s, values[1], true);
					item.activate.connect (() => {
						if (action_id != null) {
							var path = File.new_for_uri (Launcher).get_path ();
							if (path != null) {
								var desktop_info = new DesktopAppInfo.from_filename (path);
								if (desktop_info != null)
									desktop_info.launch_action (action_id, System.get_default ().context);
							}
							return;
						}
						try {
							AppInfo.create_from_commandline (values[0], null, AppInfoCreateFlags.NONE).launch (null, null);
						} catch { }
					});
					items.add (item);
				}
			}

			// 4. Window & App Controls Section
			items.add (new Gtk.SeparatorMenuItem ());
			if (windows.size > 0) {
				var new_win_item = create_menu_item ("新建窗口", "window-new", true);
				new_win_item.activate.connect (() => {
					launch ();
				});
				items.add (new_win_item);

				var top_item = create_menu_item (windows.size > 1 ? "切换下一个窗口" : "置顶应用窗口", "go-top", true);
				top_item.activate.connect (() => {
					WindowControl.queue_command (windows[0].Id, "activate");
				});
				items.add (top_item);

				if (windows.size > 1) {
					var expand_item = create_menu_item (is_expanded ? "折叠窗口卡片" : "展开窗口卡片", "view-list-details", true);
					expand_item.activate.connect (() => {
						if (is_expanded)
							collapse_cards ();
						else
							expand_cards ();
					});
					items.add (expand_item);

					var close_all_item = create_menu_item ("关闭全部窗口", "window-close", true);
					close_all_item.activate.connect (() => {
						foreach (var win in windows) {
							WindowControl.queue_command (win.Id, "close");
						}
					});
					items.add (close_all_item);
				} else {
					var close_item = create_menu_item ("关闭窗口", "window-close", true);
					string target_id = windows[0].Id;
					close_item.activate.connect (() => {
						WindowControl.queue_command (target_id, "close");
					});
					items.add (close_item);
				}
			} else {
				var launch_item = create_menu_item ("启动应用", "media-playback-start", true);
				launch_item.activate.connect (() => {
					launch ();
				});
				items.add (launch_item);
			}

			// 5. Pin / Unpin from Dock
			unowned DefaultApplicationDockItemProvider? default_provider = (Container as DefaultApplicationDockItemProvider);
			if (default_provider != null
				&& !default_provider.Prefs.LockItems
				&& !is_window ()) {
				bool is_pinned = !(this is TransientDockItem);
				if (is_pinned) {
					var unpin_item = create_menu_item ("从 Dock 移除", "list-remove", true);
					unpin_item.activate.connect (() => pin_launcher ());
					items.add (unpin_item);
				} else {
					var pin_item = create_menu_item ("固定到 Dock", "bookmark-new", true);
					pin_item.activate.connect (() => pin_launcher ());
					items.add (pin_item);
				}
			}

			// 5.1 Custom Icon from system library
			if (!is_window ()) {
				bool is_pinned = !(this is TransientDockItem);
				if (is_pinned) {
					items.add (new Gtk.SeparatorMenuItem ());
					var icon_item = create_menu_item ("更改图标 (系统库)...", "preferences-desktop-theme", true);
					icon_item.activate.connect (() => pick_custom_icon ());
					items.add (icon_item);

					if (Prefs.CustomIcon != "") {
						var reset_icon_item = create_menu_item ("恢复默认图标", "edit-undo", true);
						reset_icon_item.activate.connect (() => reset_custom_icon ());
						items.add (reset_icon_item);
					}
				}
			}

			// 6. Native clean system preferences & quit
			items.add (new Gtk.SeparatorMenuItem ());
			var pref_item = create_menu_item ("首选项 / Preferences...", "preferences-system", true);
			pref_item.activate.connect (() => Application.get_default ().activate_action ("preferences", null));
			items.add (pref_item);

			var quit_item = create_menu_item ("退出 WayPlank / Quit", "application-exit", true);
			quit_item.activate.connect (() => Application.get_default ().activate_action ("quit", null));
			items.add (quit_item);

			return items;
		}
		
		/**
		 * {@inheritDoc}
		 */
		public override string get_drop_text ()
		{
			return _("Drop to open with %s").printf (Text);
		}
		
		/**
		 * {@inheritDoc}
		 */
		public override bool can_accept_drop (Gee.ArrayList<string> uris)
		{
			if (uris == null || uris.size == 0 || is_window ())
				return false;
			
			// 1. If application declares file or URI payload support in its Exec line (%f, %F, %u, %U)
			if (accepts_payload)
				return true;
			
			// 2. Check if URIs match supported MIME types or web schemes
			if (supported_mime_types != null && supported_mime_types.size > 0) {
				try {
					foreach (var uri in uris) {
						if (uri.has_prefix ("http://") || uri.has_prefix ("https://")) {
							foreach (var content_type in supported_mime_types) {
								if (content_type.contains ("html") || content_type.contains ("http") || content_type.contains ("url"))
									return true;
							}
						} else {
							var info = File.new_for_uri (uri).query_info (FileAttribute.STANDARD_CONTENT_TYPE, FileQueryInfoFlags.NONE);
							unowned string uri_content_type = info.get_content_type ();
							foreach (var content_type in supported_mime_types) {
								if (ContentType.is_a (uri_content_type, content_type) || ContentType.equals (uri_content_type, content_type))
									return true;
							}
						}
					}
				} catch {}
			}
			
			return false;
		}
		
		/**
		 * {@inheritDoc}
		 */
		public override bool accept_drop (Gee.ArrayList<string> uris)
		{
			if (uris == null || uris.size == 0)
				return false;

			// Visual bounce feedback on the dropped dock icon
			trigger_bounce ();

			// Launch application with files/URIs
			System.get_default ().launch_with_uris (File.new_for_uri (Prefs.Launcher), uris.to_array ());

			// If the application already has a running window, bring it forward
			var windows = WindowManager.get_default ().matching_windows (Launcher);
			if (windows.size > 0) {
				WindowControl.queue_command (windows[0].Id, "activate");
			}

			return true;
		}
		
		/**
		 * {@inheritDoc}
		 */
		protected override void load_from_launcher ()
		{
			if (Prefs == null || Prefs.Launcher == "")
				return;
			
			if (actions == null)
				actions = new Gee.ArrayList<string> ();
			if (actions_map == null)
				actions_map = new Gee.HashMap<string, string> ();
			if (supported_mime_types == null)
				supported_mime_types = new Gee.ArrayList<string> ();
			if (desktop_action_ids == null)
				desktop_action_ids = new Gee.HashMap<string, string> ();
			
			string icon, text;
			parse_launcher (Prefs.Launcher, out icon, out text, actions, actions_map, supported_mime_types, desktop_action_ids);
			if (Prefs.CustomIcon != "")
				Icon = Prefs.CustomIcon;
			else
				Icon = icon;
			ForcePixbuf = null;
			Text = text;

			accepts_payload = false;
			try {
				var launcher_path = Filename.from_uri (Prefs.Launcher);
				var app_info = new DesktopAppInfo.from_filename (launcher_path);
				if (app_info != null && (app_info.supports_files () || app_info.supports_uris ())) {
					accepts_payload = true;
				} else {
					var kf = new KeyFile ();
					kf.load_from_file (launcher_path, KeyFileFlags.NONE);
					if (kf.has_key (KeyFileDesktop.GROUP, KeyFileDesktop.KEY_EXEC)) {
						var exec_str = kf.get_string (KeyFileDesktop.GROUP, KeyFileDesktop.KEY_EXEC);
						if (exec_str.contains ("%f") || exec_str.contains ("%F") || 
						    exec_str.contains ("%u") || exec_str.contains ("%U")) {
							accepts_payload = true;
						}
					}
				}
			} catch {}
		}
		
		/**
		 * Parses a launcher to get the text, icon and actions.
		 *
		 * @param launcher the launcher file (.desktop file) to parse
		 * @param icon the icon key from the launcher
		 * @param text the text key from the launcher
		 * @param actions a list of all actions by name
		 * @param actions_map a map of actions from name to exec;;icon
		 * @param mimes a list of all supported mime types
		 */
		public static void parse_launcher (string launcher, out string icon, out string text, Gee.ArrayList<string>? actions = null, Gee.Map<string, string>? actions_map = null, Gee.ArrayList<string>? mimes = null, Gee.Map<string, string>? desktop_action_ids = null)
		{
			icon = "";
			text = "";
			
			if (launcher == null || launcher == "")
				return;
			
			KeyFile file;
			
			try {
				file = new KeyFile ();
				file.load_from_file (Filename.from_uri (launcher), 0);
			} catch (Error e) {
				critical ("%s: %s", launcher, e.message);
				return;
			}
			
			try {
				text = file.get_locale_string (KeyFileDesktop.GROUP, KeyFileDesktop.KEY_NAME);
				
				if (file.has_key (KeyFileDesktop.GROUP, KeyFileDesktop.KEY_ICON))
					icon = file.get_locale_string (KeyFileDesktop.GROUP, KeyFileDesktop.KEY_ICON);
				
				var type = file.get_string (KeyFileDesktop.GROUP, KeyFileDesktop.KEY_TYPE);
				switch (type) {
				default:
				case KeyFileDesktop.TYPE_APPLICATION:
					break;
				case KeyFileDesktop.TYPE_DIRECTORY:
					if (icon == "")
						icon = "inode-directory";
					return;
				case KeyFileDesktop.TYPE_LINK:
					if (icon == "")
						icon = "document";
					return;	
				}
			} catch (KeyFileError e) {
				critical ("%s: %s", launcher, e.message);
				return;
			}
			
			try {
				if (mimes != null && file.has_key (KeyFileDesktop.GROUP, KeyFileDesktop.KEY_MIME_TYPE)) {
					var mimestrings = file.get_string_list (KeyFileDesktop.GROUP, KeyFileDesktop.KEY_MIME_TYPE);
					foreach (unowned string mime in mimestrings)
						mimes.add (ContentType.from_mime_type (mime));
				}
				
				string? textdomain = null;
				foreach (unowned string domain_key in SUPPORTED_GETTEXT_DOMAINS_KEYS)
					if (file.has_key (KeyFileDesktop.GROUP, domain_key)) {
						textdomain = file.get_string (KeyFileDesktop.GROUP, domain_key);
						break;
					}
				
				// get FDO Desktop Actions
				// see http://standards.freedesktop.org/desktop-entry-spec/desktop-entry-spec-latest.html#extra-actions
				// get the Unity static quicklists
				// see https://wiki.edubuntu.org/Unity/LauncherAPI#Static Quicklist entries
				if (actions != null && actions_map != null) {
					actions.clear ();
					actions_map.clear ();
					if (desktop_action_ids != null)
						desktop_action_ids.clear ();
					
					string[] keys = {DESKTOP_ACTION_KEY, UNITY_QUICKLISTS_KEY};
					
					foreach (unowned string key in keys) {
						if (!file.has_key (KeyFileDesktop.GROUP, key))
							continue;
						
						foreach (unowned string action in file.get_string_list (KeyFileDesktop.GROUP, key)) {
							var group = DESKTOP_ACTION_GROUP_NAME.printf (action);
							if (!file.has_group (group)) {
								group = UNITY_QUICKLISTS_SHORTCUT_GROUP_NAME.printf (action);
								if (!file.has_group (group))
									continue;
							}
							
							// check for TargetEnvironment
							if (file.has_key (group, UNITY_QUICKLISTS_TARGET_KEY)) {
								var target = file.get_string (group, UNITY_QUICKLISTS_TARGET_KEY);
								if (target != UNITY_QUICKLISTS_TARGET_VALUE && target != "Plank")
									continue;
							}
							
							// check for NotShowIn
							if (file.has_key (group, KeyFileDesktop.KEY_NOT_SHOW_IN)) {
								var found = false;
								
								foreach (unowned string s in file.get_string_list (group, KeyFileDesktop.KEY_NOT_SHOW_IN))
									if (s == "Plank") {
										found = true;
										break;
									}
								
								if (found)
									continue;
							}
							
							// check for OnlyShowIn
							if (file.has_key (group, KeyFileDesktop.KEY_ONLY_SHOW_IN)) {
								var found = false;
								
								foreach (unowned string s in file.get_string_list (group, KeyFileDesktop.KEY_ONLY_SHOW_IN))
									if (s == UNITY_QUICKLISTS_TARGET_VALUE || s == "Plank") {
										found = true;
										break;
									}
								
								if (!found)
									continue;
							}
							
							var action_name = file.get_locale_string (group, KeyFileDesktop.KEY_NAME);
							
							var action_icon = "";
							if (file.has_key (group, KeyFileDesktop.KEY_ICON))
								action_icon = file.get_locale_string (group, KeyFileDesktop.KEY_ICON);
							
							var action_exec = "";
							if (file.has_key (group, KeyFileDesktop.KEY_EXEC))
								action_exec = file.get_string (group, KeyFileDesktop.KEY_EXEC);
							
							// apply given gettext-domain if available
							if (textdomain != null)
								action_name = GLib.dgettext (textdomain, action_name).dup ();
							
							actions.add (action_name);
							actions_map.set (action_name, "%s;;%s".printf (action_exec, action_icon));
							if (desktop_action_ids != null) {
								if (key == DESKTOP_ACTION_KEY && group == DESKTOP_ACTION_GROUP_NAME.printf (action))
									desktop_action_ids.set (action_name, action);
								else
									desktop_action_ids.unset (action_name);
							}
						}
					}
				}
			} catch (KeyFileError e) {
				critical ("%s: %s", launcher, e.message);
				return;
			}
		}
		
		
		/**
		 * Get current libunity dbusname
		 *
		 * @return the dbusname which provides the LauncherEntry interface, or NULL
		 */
		public unowned string? get_unity_dbusname ()
		{
			return unity_dbusname;
		}
		
		/**
		 * Whether this item provides information worth showing
		 */
		public bool has_unity_info ()
		{
			return (ProgressVisible || CountVisible);
		}
		
		/**
		 * Update this item's remote libunity value based on the given data
		 *
		 * @param sender_name the corressponding dbusname
		 * @param prop_iter the data in a standardize format from libunity
		 */
		public void unity_update (string sender_name, VariantIter prop_iter)
		{
			unity_dbusname = sender_name;
			
			string prop_key;
			Variant prop_value;
			
			while (prop_iter.next ("{sv}", out prop_key, out prop_value)) {
				if (prop_key == "count") {
					var val = prop_value.get_int64 ();
					if (Count != val)
						Count = val;
				} else if (prop_key == "count-visible") {
					var val = prop_value.get_boolean ();
					if (CountVisible != val)
						CountVisible = val;
				} else if (prop_key == "progress") {
					var val = nround (prop_value.get_double (), 3U);
					if (Progress != val)
						Progress = val;
				} else if (prop_key == "progress-visible") {
					var val = prop_value.get_boolean ();
					if (ProgressVisible != val)
						ProgressVisible = val;
				} else if (prop_key == "urgent") {
					set_urgent (prop_value.get_boolean ());
#if HAVE_DBUSMENU
				} else if (prop_key == "quicklist") {
					/* The value is the object path of the dbusmenu */
					unowned string dbus_path = prop_value.get_string ();
					// Make sure we don't update our Quicklist instance if isn't necessary
					if (Quicklist == null || Quicklist.dbus_object != dbus_path)
						if (dbus_path != "") {
							Logger.verbose ("Loading dynamic quicklists for %s (%s)", Text, sender_name);
							Quicklist = new DbusmenuGtk.Client (sender_name, dbus_path);
						} else {
							Quicklist = null;
						}
#endif
				}
			}
		}
		
		/**
		 * Reset this item's remote libunity values
		 */
		public void unity_reset ()
		{
			unity_dbusname = null;
			
			Count = 0;
			CountVisible = false;
			Progress = 0.0;
			ProgressVisible = false;
			set_urgent (false);
#if HAVE_DBUSMENU
			Quicklist = null;
#endif
		}

	}
}
