//
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
	 * Service for tracking the desktop environment's Light/Dark mode via
	 * the XDG Desktop Portal (FreeDesktop standard for KDE Plasma, GNOME, etc.)
	 */
	public class SystemTheme : GLib.Object
	{
		static SystemTheme? default_instance = null;

		public bool is_dark { get; private set; default = false; }
		public signal void theme_changed (bool is_dark);

		uint subscription_id = 0;
		DBusConnection? bus = null;

		public static SystemTheme get_default ()
		{
			if (default_instance == null) {
				default_instance = new SystemTheme ();
			}
			return default_instance;
		}

		construct
		{
			refresh_state ();
			init_dbus_listener ();

			// Fallback: observe GTK theme name changes
			unowned Gtk.Settings? gtk_settings = Gtk.Settings.get_default ();
			if (gtk_settings != null) {
				gtk_settings.notify["gtk-theme-name"].connect (() => {
					refresh_state ();
				});
			}
		}

		~SystemTheme ()
		{
			if (bus != null && subscription_id > 0) {
				bus.signal_unsubscribe (subscription_id);
				subscription_id = 0;
			}
		}

		public void refresh_state ()
		{
			bool detected_dark = false;
			bool detected = false;

			// 1. Try XDG Desktop Portal (standard across modern Wayland desktops: KDE Plasma 6+, GNOME 42+)
			try {
				var session_bus = Bus.get_sync (BusType.SESSION, null);
				var res = session_bus.call_sync (
					"org.freedesktop.portal.Desktop",
					"/org/freedesktop/portal/desktop",
					"org.freedesktop.portal.Settings",
					"Read",
					new Variant ("(ss)", "org.freedesktop.appearance", "color-scheme"),
					null,
					DBusCallFlags.NONE,
					500,
					null
				);

				Variant outer_v;
				res.get ("(v)", out outer_v);
				Variant val = outer_v;
				while (val.is_of_type (VariantType.VARIANT))
					val = val.get_variant ();

				if (val.is_of_type (VariantType.UINT32)) {
					uint32 code = val.get_uint32 ();
					if (code == 1) { // 1: Prefer dark
						detected_dark = true;
						detected = true;
					} else if (code == 2) { // 2: Prefer light
						detected_dark = false;
						detected = true;
					}
				}
			} catch (Error e) {
				debug ("SystemTheme: portal read error: %s", e.message);
			}

			// 2. Fallback to GNOME Settings schema if portal was inconclusive (code == 0)
			if (!detected) {
				var source = SettingsSchemaSource.get_default ();
				if (source != null && source.lookup ("org.gnome.desktop.interface", true) != null) {
					var gs = new GLib.Settings ("org.gnome.desktop.interface");
					var scheme = gs.get_string ("color-scheme");
					if (scheme != null) {
						if (scheme == "prefer-dark") {
							detected_dark = true;
							detected = true;
						} else if (scheme == "prefer-light") {
							detected_dark = false;
							detected = true;
						}
					}
				}
			}

			// 3. Fallback to GTK theme name heuristics
			if (!detected) {
				var theme_name = Gtk.Settings.get_default ().gtk_theme_name ?? "";
				if (theme_name.down ().contains ("dark") || theme_name.down ().contains ("black")) {
					detected_dark = true;
				} else {
					detected_dark = false;
				}
			}

			if (is_dark != detected_dark) {
				is_dark = detected_dark;
				theme_changed (is_dark);
			}
		}

		void init_dbus_listener ()
		{
			try {
				bus = Bus.get_sync (BusType.SESSION, null);
				subscription_id = bus.signal_subscribe (
					"org.freedesktop.portal.Desktop",
					"org.freedesktop.portal.Settings",
					"SettingChanged",
					"/org/freedesktop/portal/desktop",
					null,
					DBusSignalFlags.NONE,
					(DBusSignalCallback) handle_portal_setting_changed
				);
			} catch (Error e) {
				warning ("SystemTheme: failed to subscribe to portal settings: %s", e.message);
			}
		}

		[CCode (instance_pos = -1)]
		void handle_portal_setting_changed (DBusConnection connection, string sender_name, string object_path,
			string interface_name, string signal_name, Variant parameters)
		{
			string ns, key;
			Variant val_outer;
			parameters.get ("(ssv)", out ns, out key, out val_outer);
			if (ns == "org.freedesktop.appearance" && key == "color-scheme") {
				Variant val = val_outer;
				while (val.is_of_type (VariantType.VARIANT))
					val = val.get_variant ();

				if (val.is_of_type (VariantType.UINT32)) {
					uint32 code = val.get_uint32 ();
					bool new_dark = (code == 1);
					if (is_dark != new_dark) {
						is_dark = new_dark;
						theme_changed (is_dark);
					}
				}
			}
		}
	}
}

