//
//  Copyright (C) 2011-2012 Robert Dyer, Michal Hruby, Rico Tzschichholz
//  Copyright (C) 2026 Sergio Melas
//  Copyright (C) 2026 史有虎 (IFtiger-hu)
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
	/**
	 * A divider between dock items.
	 *
	 * Auto separators (no .dockitem) are inserted between pinned / transient / trash
	 * groups and are not user-removable. User separators are backed by
	 * separator-*.dockitem files (Launcher = docklet://separator) so their place
	 * in FreeDockItems / DockItems survives restart.
	 */
	public class SeparatorDockItem : DockItem
	{
		public const string LAUNCHER_URI = "docklet://separator";
		const int THICKNESS = 2;
		
		public Color BarColor { get; set; default = Color () { red = 0.0, green = 0.0, blue = 0.0, alpha = 1.0 }; }
		bool horizontal = true;

		public SeparatorDockItem ()
		{
			GLib.Object (Prefs: new DockItemPreferences ());
		}

		public SeparatorDockItem.with_dockitem_file (GLib.File file)
		{
			GLib.Object (Prefs: new DockItemPreferences.with_file (file));
		}

		public static bool launcher_is_separator (string? launcher)
		{
			return launcher != null
				&& (launcher == LAUNCHER_URI || launcher.has_prefix (LAUNCHER_URI + "/"));
		}

		public bool is_user_separator ()
		{
			return launcher_is_separator (Prefs != null ? Prefs.Launcher : null);
		}
		
		construct
		{
			Text = "";
			Icon = "";
			Button = PopupButton.RIGHT;
			notify["BarColor"].connect (() => reset_icon_buffer ());
		}

		public void set_horizontal_orientation (bool value)
		{
			if (horizontal == value)
				return;
			horizontal = value;
			reset_icon_buffer ();
		}
		
		/**
		 * {@inheritDoc}
		 */
		protected override void draw_icon (Surface surface)
		{
			unowned Cairo.Context cr = surface.Context;
			var w = surface.Width;
			var h = surface.Height;
			if (w <= 0 || h <= 0)
				return;

			var bar_width = horizontal ? THICKNESS : int.max (10, (int) Math.floor (w * 0.52));
			var bar_height = horizontal ? int.max (10, (int) Math.floor (h * 0.52)) : THICKNESS;
			var bar_x = (w - bar_width) / 2.0;
			var bar_y = (h - bar_height) / 2.0;
			var radius = THICKNESS / 2.0;
			
			cr.save ();
			cr.set_source_rgba (BarColor.red, BarColor.green, BarColor.blue, BarColor.alpha);
			cr.new_sub_path ();
			cr.arc (bar_x + bar_width - radius, bar_y + radius, radius, -Math.PI_2, 0);
			cr.arc (bar_x + bar_width - radius, bar_y + bar_height - radius, radius, 0, Math.PI_2);
			cr.arc (bar_x + radius, bar_y + bar_height - radius, radius, Math.PI_2, Math.PI);
			cr.arc (bar_x + radius, bar_y + radius, radius, Math.PI, -Math.PI_2);
			cr.close_path ();
			cr.fill ();
			cr.restore ();
		}
		
		/**
		 * {@inheritDoc}
		 */
		protected override AnimationType on_clicked (PopupButton button, Gdk.ModifierType mod, uint32 event_time)
		{
			return AnimationType.NONE;
		}
		
		/**
		 * {@inheritDoc}
		 */
		public override Gee.ArrayList<Gtk.MenuItem> get_menu_items ()
		{
			var items = new Gee.ArrayList<Gtk.MenuItem> ();
			if (!is_user_separator ())
				return items;

			unowned DefaultApplicationDockItemProvider? provider = (Container as DefaultApplicationDockItemProvider);
			if (provider != null && provider.Prefs.LockItems)
				return items;

			var remove_item = create_literal_menu_item ("移除分隔符");
			remove_item.activate.connect (() => {
				unowned DockContainer? container = Container;
				unowned DockController? dock = get_dock ();
				if (container != null && container.Elements.contains (this))
					container.remove (this);
				@delete ();
				if (dock != null)
					dock.schedule_serialize_item_positions ();
			});
			items.add (remove_item);
			return items;
		}
		
		/**
		 * {@inheritDoc}
		 */
		public override bool can_be_removed ()
		{
			return is_user_separator ();
		}
		
		/**
		 * {@inheritDoc}
		 */
		public override bool is_valid ()
		{
			return true;
		}
	}
}
