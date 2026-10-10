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
	 * A dock item for the dock itself.  Has things like about, help, quit etc.
	 */
	struct DockletMenuEntry {
		public string label;
		public string uri;
	}

	public class PlankDockItem : DockItem
	{
		static PlankDockItem? instance;
		
		public static unowned PlankDockItem get_instance ()
		{
			if (instance == null)
				instance = new PlankDockItem ();
			
			return instance;
		}
		
		PlankDockItem ()
		{
			GLib.Object (Prefs: new DockItemPreferences (), Text: "Plank", Icon: "plank");
		}
		
		construct
		{
			// if plank is pinned indicate that it is running while it isnt user-visible
			Indicator = IndicatorState.SINGLE;
		}
		
		/**
		 * {@inheritDoc}
		 */
		public override bool can_be_removed ()
		{
			return false;
		}
		
		/**
		 * {@inheritDoc}
		 */
		protected override AnimationType on_clicked (PopupButton button, Gdk.ModifierType mod, uint32 event_time)
		{
			Application.get_default ().activate_action ("preferences", null);
			
			return AnimationType.DARKEN;
		}
		
		/**
		 * {@inheritDoc}
		 */
		public override Gee.ArrayList<Gtk.MenuItem> get_menu_items ()
		{
			var items = new Gee.ArrayList<Gtk.MenuItem> ();
			
			unowned DockController? controller = get_dock ();
			if (controller != null) {
				unowned DefaultApplicationDockItemProvider? default_provider = controller.default_provider as DefaultApplicationDockItemProvider;
				if (default_provider != null) {
					var docklets_item = create_menu_item ("插件 / Docklets", "system-run", true);
					var docklets_menu = new Gtk.Menu ();
					DockletMenuEntry[] docklets = {
						{ "回收站 (Trash)", "docklet://trash" },
						{ "模拟时钟 (Clock)", "docklet://clock" },
						{ "数字时钟 (Digital Clock)", "docklet://digital-clock" },
						{ "电池状态 (Battery)", "docklet://battery" },
						{ "CPU / 内存监控 (CPU/RAM)", "docklet://cpu" },
						{ "显示桌面 (Show Desktop)", "docklet://desktop" },
						{ "媒体播放器 (Media Player)", "docklet://mpris" },
						{ "音量控制 (Volume)", "docklet://volume" },
						{ "截屏工具 (Screenshot)", "docklet://screenshot" },
						{ "电源与会话 (Session)", "docklet://session" },
						{ "首选项设置 (Preferences)", "docklet://preferences" }
					};
					foreach (var d in docklets) {
						var d_uri = d.uri;
						var c_item = new Gtk.CheckMenuItem.with_label (d.label);
						c_item.active = (default_provider.item_for_uri (d_uri) != null);
						c_item.toggled.connect (() => {
							if (c_item.active) {
								if (default_provider.item_for_uri (d_uri) == null)
									default_provider.add_item_with_uri (d_uri);
							} else {
								unowned DockItem? di = default_provider.item_for_uri (d_uri);
								if (di != null)
									di.delete ();
							}
						});
						docklets_menu.add (c_item);
					}
					
					docklets_menu.show_all ();
					docklets_item.set_submenu (docklets_menu);
					items.add (docklets_item);
					items.add (new Gtk.SeparatorMenuItem ());
				}
			}
			
			var item = create_menu_item ("首选项 / Preferences...", "preferences-system", true);
			item.activate.connect (() => Application.get_default ().activate_action ("preferences", null));
			items.add (item);

			item = create_menu_item ("关于 WayPlank / About...", "help-about", true);
			item.activate.connect (() => Application.get_default ().activate_action ("about", null));
			items.add (item);
			
			// No explicit quit-item on elementary OS
			if (!environment_is_session_desktop (XdgSessionDesktop.PANTHEON)) {
				items.add (new Gtk.SeparatorMenuItem ());
			
				item = create_menu_item ("退出 WayPlank / Quit", "application-exit", true);
				item.activate.connect (() => Application.get_default ().activate_action ("quit", null));
				items.add (item);
			}
			
			return items;
		}
	}
}
