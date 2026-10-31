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
	public class EjectorDockItem : DockItem
	{
		const string ICON_NAMES = "media-eject;;drive-removable-media;;media-eject-symbolic";

		private GLib.VolumeMonitor? volume_monitor = null;
		private ulong sig_mount_added = 0;
		private ulong sig_mount_removed = 0;
		private ulong sig_mount_changed = 0;
		private ulong sig_volume_added = 0;
		private ulong sig_volume_removed = 0;
		private ulong sig_drive_connected = 0;
		private ulong sig_drive_disconnected = 0;

		public EjectorDockItem ()
		{
			GLib.Object (Prefs: new DockItemPreferences ());
		}

		public EjectorDockItem.with_dockitem_file (GLib.File file)
		{
			GLib.Object (Prefs: new DockItemPreferences.with_file (file));
		}

		construct
		{
			Text = "可移动磁盘";
			Icon = ICON_NAMES;
			Button = PopupButton.RIGHT;

			volume_monitor = GLib.VolumeMonitor.get ();
			if (volume_monitor != null) {
				sig_mount_added = volume_monitor.mount_added.connect (on_storage_changed);
				sig_mount_removed = volume_monitor.mount_removed.connect (on_storage_changed);
				sig_mount_changed = volume_monitor.mount_changed.connect (on_storage_changed);
				sig_volume_added = volume_monitor.volume_added.connect (on_storage_changed);
				sig_volume_removed = volume_monitor.volume_removed.connect (on_storage_changed);
				sig_drive_connected = volume_monitor.drive_connected.connect (on_storage_changed);
				sig_drive_disconnected = volume_monitor.drive_disconnected.connect (on_storage_changed);
			}

			update_ejector_status ();
		}

		private void stop_monitoring ()
		{
			if (volume_monitor != null) {
				if (sig_mount_added != 0) volume_monitor.disconnect (sig_mount_added);
				if (sig_mount_removed != 0) volume_monitor.disconnect (sig_mount_removed);
				if (sig_mount_changed != 0) volume_monitor.disconnect (sig_mount_changed);
				if (sig_volume_added != 0) volume_monitor.disconnect (sig_volume_added);
				if (sig_volume_removed != 0) volume_monitor.disconnect (sig_volume_removed);
				if (sig_drive_connected != 0) volume_monitor.disconnect (sig_drive_connected);
				if (sig_drive_disconnected != 0) volume_monitor.disconnect (sig_drive_disconnected);
				volume_monitor = null;
			}
		}

		~EjectorDockItem ()
		{
			stop_monitoring ();
		}

		public override void @delete ()
		{
			stop_monitoring ();
			base.@delete ();
		}

		public override bool is_valid ()
		{
			return true;
		}

		private void on_storage_changed ()
		{
			update_ejector_status ();
		}

		public GLib.List<GLib.Mount> get_removable_mounts ()
		{
			var list = new GLib.List<GLib.Mount> ();
			if (volume_monitor == null)
				return list;

			foreach (var mount in volume_monitor.get_mounts ()) {
				var volume = mount.get_volume ();
				var drive = (volume != null) ? volume.get_drive () : mount.get_drive ();
				bool is_removable = false;

				if (drive != null && (drive.is_removable () || drive.is_media_removable () || drive.can_eject () || drive.can_stop ())) {
					is_removable = true;
				} else if (volume != null && volume.can_eject ()) {
					is_removable = true;
				} else if (mount.can_eject () || mount.can_unmount ()) {
					var root = mount.get_default_location ();
					string? path = (root != null) ? root.get_path () : null;
					if (path != null && (path.has_prefix ("/media") || path.has_prefix ("/run/media") || path.has_prefix ("/mnt"))) {
						is_removable = true;
					}
				}

				if (is_removable) {
					list.append (mount);
				}
			}

			return list;
		}

		public void update_ejector_status ()
		{
			var mounts = get_removable_mounts ();
			uint count = mounts.length ();

			if (count > 0) {
				Count = count;
				CountVisible = true;
				Text = "可移动磁盘 (已挂载 %u 个)".printf (count);
			} else {
				Count = 0;
				CountVisible = false;
				Text = "可移动磁盘 (未连接设备)";
			}

			reset_icon_buffer ();
		}

		public void eject_mount (GLib.Mount mount)
		{
			string name = mount.get_name ();
			var op = new GLib.MountOperation ();

			mount.unmount_with_operation.begin (GLib.MountUnmountFlags.NONE, op, null, (obj, res) => {
				try {
					mount.unmount_with_operation.end (res);
					notify_ejected (name);
					update_ejector_status ();
				} catch (GLib.Error e) {
					warning ("Ejector: failed to unmount '%s': %s", name, e.message);
				}
			});
		}

		public void eject_all ()
		{
			var mounts = get_removable_mounts ();
			foreach (var m in mounts) {
				eject_mount (m);
			}
		}

		private void notify_ejected (string drive_name)
		{
			try {
				var bus = GLib.Bus.get_sync (GLib.BusType.SESSION, null);
				var builder = new GLib.VariantBuilder (new GLib.VariantType ("(susssasa{sv}i)"));
				builder.add ("s", "WayPlank");
				builder.add ("u", 0U);
				builder.add ("s", "media-eject");
				builder.add ("s", "可以安全拔出");
				builder.add ("s", "设备 '%s' 已安全卸载。".printf (drive_name));
				builder.add ("as", new string[0]);
				builder.open (new GLib.VariantType ("a{sv}"));
				builder.close ();
				builder.add ("i", 3000);

				bus.call.begin (
					"org.freedesktop.Notifications",
					"/org/freedesktop/Notifications",
					"org.freedesktop.Notifications",
					"Notify",
					builder.end (),
					null,
					GLib.DBusCallFlags.NONE,
					-1,
					null
				);
			} catch (GLib.Error e) {
				// Fallback to notify-send
				try {
					Process.spawn_command_line_async ("notify-send -i media-eject '%s' '%s'".printf ("可以安全拔出", drive_name));
				} catch (Error e2) { }
			}
		}

		protected override AnimationType on_clicked (PopupButton button, Gdk.ModifierType mod, uint32 event_time)
		{
			if (button == PopupButton.LEFT) {
				var mounts = get_removable_mounts ();
				if (mounts.length () == 1) {
					eject_mount (mounts.data);
					return AnimationType.BOUNCE;
				} else if (mounts.length () > 1) {
					var menu = new Gtk.Menu ();
					foreach (var m in mounts) {
						var item = new Gtk.MenuItem.with_label ("弹出 '%s'".printf (m.get_name ()));
						item.activate.connect (() => eject_mount (m));
						menu.append (item);
					}
					var sep = new Gtk.SeparatorMenuItem ();
					menu.append (sep);
					var item_all = new Gtk.MenuItem.with_label ("弹出所有设备");
					item_all.activate.connect (() => eject_all ());
					menu.append (item_all);

					menu.show_all ();
					menu.popup_at_pointer (null);
					return AnimationType.BOUNCE;
				} else {
					notify_no_devices ();
					return AnimationType.NONE;
				}
			}

			return AnimationType.NONE;
		}

		private void notify_no_devices ()
		{
			try {
				Process.spawn_command_line_async ("notify-send -i drive-removable-media 'WayPlank' '%s'".printf ("未连接可移动设备"));
			} catch (Error e) { }
		}

		public override Gee.ArrayList<Gtk.MenuItem> get_menu_items ()
		{
			var items = new Gee.ArrayList<Gtk.MenuItem> ();
			var mounts = get_removable_mounts ();

			if (mounts.length () > 0) {
				foreach (var m in mounts) {
					var eject_item = create_menu_item ("弹出 '%s'".printf (m.get_name ()), "media-eject", true);
					eject_item.activate.connect (() => eject_mount (m));
					items.add (eject_item);
				}

				if (mounts.length () > 1) {
					var eject_all_item = create_menu_item ("弹出所有设备", "media-eject", true);
					eject_all_item.activate.connect (() => eject_all ());
					items.add (eject_all_item);
				}
			} else {
				var empty_item = create_menu_item ("无已连接的可移动设备", "drive-removable-media", false);
				empty_item.set_sensitive (false);
				items.add (empty_item);
			}

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
