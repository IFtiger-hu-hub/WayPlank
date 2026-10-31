//
//  Copyright (C) 2011-2012 Robert Dyer, Michal Hruby, Rico Tzschichholz
//  Copyright (C) 2026 Sergio Melas
//  Copyright (C) 2026 史有虎 (IFtiger-hu)
//
//  This file is part of kde-dockbar.
//
//  kde-dockbar is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//

namespace Plank
{
	public class ScreenshotDockItem : DockItem
	{
		const string ICON = "applets-screenshooter;;accessories-screenshot;;spectacle;;camera-photo";
		
		public ScreenshotDockItem ()
		{
			GLib.Object (Prefs: new DockItemPreferences ());
		}
		
		public ScreenshotDockItem.with_dockitem_file (GLib.File file)
		{
			GLib.Object (Prefs: new DockItemPreferences.with_file (file));
		}
		
		construct
		{
			Icon = ICON;
			Text = "截取屏幕";
			Button = PopupButton.RIGHT;
		}
		
		public override bool is_valid ()
		{
			return true;
		}

		static bool invoke_portal_screenshot (bool interactive)
		{
			try {
				var bus = Bus.get_sync (BusType.SESSION, null);
				var builder = new VariantBuilder (new VariantType ("a{sv}"));
				builder.add ("{sv}", "interactive", new Variant.boolean (interactive));
				bus.call_sync ("org.freedesktop.portal.Desktop", "/org/freedesktop/portal/desktop",
					"org.freedesktop.portal.Screenshot", "Screenshot",
					new Variant ("(sa{sv})", "", builder),
					null, DBusCallFlags.NONE, 2000, null);
				return true;
			} catch (Error e) {
				warning ("Failed to invoke XDG screenshot portal: %s", e.message);
				return false;
			}
		}

		public void capture_interactive ()
		{
			if (Environment.find_program_in_path ("spectacle") != null) {
				try {
					Process.spawn_command_line_async ("spectacle -r");
					return;
				} catch (Error e) {
					warning ("Failed to launch spectacle: %s", e.message);
				}
			}
			invoke_portal_screenshot (true);
		}
		
		public void capture_fullscreen ()
		{
			if (Environment.find_program_in_path ("spectacle") != null) {
				try {
					Process.spawn_command_line_async ("spectacle -f");
					return;
				} catch (Error e) {
					warning ("Failed to launch spectacle: %s", e.message);
				}
			}
			invoke_portal_screenshot (false);
		}
		
		public void capture_window ()
		{
			if (Environment.find_program_in_path ("spectacle") != null) {
				try {
					Process.spawn_command_line_async ("spectacle -a");
					return;
				} catch (Error e) {
					warning ("Failed to launch spectacle: %s", e.message);
				}
			}
			capture_interactive ();
		}

		public void open_folder ()
		{
			var pic_dir = Environment.get_user_special_dir (UserDirectory.PICTURES) ?? Environment.get_home_dir ();
			var screenshots_dir = Path.build_filename (pic_dir, "Screenshots");
			var target = FileUtils.test (screenshots_dir, FileTest.IS_DIR) ? screenshots_dir : pic_dir;
			try {
				AppInfo.launch_default_for_uri (Filename.to_uri (target), null);
			} catch (Error e) {
				warning ("Failed to open screenshots folder: %s", e.message);
			}
		}

		protected override AnimationType on_clicked (PopupButton button, Gdk.ModifierType mod, uint32 event_time)
		{
			if (button == PopupButton.LEFT) {
				capture_interactive ();
				return AnimationType.NONE;
			}
			return AnimationType.NONE;
		}

		public override Gee.ArrayList<Gtk.MenuItem> get_menu_items ()
		{
			var items = new Gee.ArrayList<Gtk.MenuItem> ();
			
			var area_item = create_menu_item ("区域截图...", "applets-screenshooter", true);
			area_item.activate.connect (capture_interactive);
			items.add (area_item);
			
			var full_item = create_menu_item ("全屏截图", "video-display", true);
			full_item.activate.connect (capture_fullscreen);
			items.add (full_item);
			
			var win_item = create_menu_item ("活动窗口截图", "window-new", true);
			win_item.activate.connect (capture_window);
			items.add (win_item);
			
			items.add (new Gtk.SeparatorMenuItem ());
			
			var folder_item = create_menu_item ("打开截图文件夹", "folder-pictures", true);
			folder_item.activate.connect (open_folder);
			items.add (folder_item);

			items.add (new Gtk.SeparatorMenuItem ());
			
			var remove_item = create_menu_item ("从 Dock 栏移除(_R)", "edit-delete", true);
			remove_item.activate.connect (() => {
				this.@delete ();
			});
			items.add (remove_item);
			
			return items;
		}
	}
}
