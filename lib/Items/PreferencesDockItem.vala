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
	public class PreferencesDockItem : DockItem
	{
		const string ICON_NAMES = "plank;;wayplank;;preferences-other;;configure;;preferences-system";

		public PreferencesDockItem ()
		{
			GLib.Object (Prefs: new DockItemPreferences ());
		}

		public PreferencesDockItem.with_dockitem_file (GLib.File file)
		{
			GLib.Object (Prefs: new DockItemPreferences.with_file (file));
		}

		construct
		{
			Text = "首选项";
			Icon = ICON_NAMES;
			Button = PopupButton.RIGHT;
		}

		public override bool is_valid ()
		{
			return true;
		}

		public override bool can_be_removed ()
		{
			return true;
		}

		public override void delete ()
		{
			unowned DockController? dock = get_dock ();
			if (dock != null && dock.prefs.SystemMenuAccess == 4) {
				dock.prefs.SystemMenuAccess = 2;
			}
			base.delete ();
		}

		public void open_preferences ()
		{
			Application.get_default ().activate_action ("preferences", null);
		}

		protected override AnimationType on_clicked (PopupButton button, Gdk.ModifierType mod, uint32 event_time)
		{
			if (button == PopupButton.LEFT) {
				unowned DockController? dock = get_dock ();
				if (dock != null && dock.prefs.CategorizeItems && dock.prefs.AccordionDocklets && dock.prefs.AccordionClickToExpand) {
					unowned DefaultApplicationDockItemProvider? app_prov = dock.default_provider as DefaultApplicationDockItemProvider;
					if (app_prov != null && !app_prov.docklets_expanded && app_prov.get_docklet_count () > 1) {
						app_prov.expand_docklets ();
						return AnimationType.BOUNCE;
					}
				}
				open_preferences ();
				return AnimationType.BOUNCE;
			}

			return AnimationType.NONE;
		}

		public static void append_full_system_menu (DockController? controller, Gee.ArrayList<Gtk.MenuItem> items)
		{
			items.add (new Gtk.SeparatorMenuItem ());

			if (controller != null) {
				unowned DefaultApplicationDockItemProvider? default_provider = controller.default_provider as DefaultApplicationDockItemProvider;
				if (default_provider != null) {
					var docklets_item = DockElement.create_menu_item ("小组件(_D)", "system-run", true);
					var docklets_menu = new Gtk.Menu ();
					DockletMenuEntry[] docklets = {
						{ "废纸篓(_T)", "docklet://trash" },
						{ "指针时钟(_A)", "docklet://clock" },
						{ "数字时钟(_D)", "docklet://digital-clock" },
						{ "电池(_B)", "docklet://battery" },
						{ "CPU / 内存监视器(_C)", "docklet://cpu" },
						{ "显示桌面(_S)", "docklet://desktop" },
						{ "媒体播放器(_M)", "docklet://mpris" },
						{ "音量控制(_V)", "docklet://volume" },
						{ "截图工具(_S)", "docklet://screenshot" },
						{ "会话与电源(_S)", "docklet://session" },
						{ "屏幕亮度(_S)", "docklet://brightness" },
						{ "可移动磁盘(_R)", "docklet://ejector" },
						{ "天气预报(_W)", "docklet://weather" },
						{ "网络 / Wi-Fi(_N)", "docklet://network" },
						{ "勿扰模式(_D)", "docklet://dnd" }
					};
					foreach (var d in docklets) {
						var d_uri = d.uri;
						var c_item = new Gtk.CheckMenuItem.with_mnemonic (d.label);
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

			var pref_item = DockElement.create_menu_item ("首选项(_P)...", "preferences-system", true);
			pref_item.activate.connect (() => Application.get_default ().activate_action ("preferences", null));
			items.add (pref_item);

			var appearance_item = DockElement.create_menu_item ("外观设置(_A)...", "preferences-desktop-theme", true);
			appearance_item.activate.connect (() => Application.get_default ().activate_action ("preferences-appearance", null));
			items.add (appearance_item);

			var behaviour_item = DockElement.create_menu_item ("行为设置(_B)...", "preferences-desktop", true);
			behaviour_item.activate.connect (() => Application.get_default ().activate_action ("preferences-behaviour", null));
			items.add (behaviour_item);

			var apps_item = DockElement.create_menu_item ("应用程序管理(_P)...", "applications-other", true);
			apps_item.activate.connect (() => Application.get_default ().activate_action ("preferences-applications", null));
			items.add (apps_item);

			var docklets_tab_item = DockElement.create_menu_item ("小组件管理(_D)...", "preferences-plugin", true);
			docklets_tab_item.activate.connect (() => Application.get_default ().activate_action ("preferences-docklets", null));
			items.add (docklets_tab_item);

			var shortcuts_item = DockElement.create_menu_item ("快捷键与鼠标手势(_S)...", "help-browser");
			shortcuts_item.activate.connect (() => Application.get_default ().activate_action ("shortcuts", null));
			items.add (shortcuts_item);

			var guide_item = DockElement.create_menu_item ("使用指南...", "help-browser", true);
			guide_item.activate.connect (() => Application.get_default ().activate_action ("guide", null));
			items.add (guide_item);

			var report_item = DockElement.create_menu_item ("在线反馈问题(_B)...", "tools-report-bug");
			report_item.activate.connect (() => Application.get_default ().activate_action ("help", null));
			items.add (report_item);

			var about_item = DockElement.create_menu_item ("关于(_A)", "help-about", true);
			about_item.activate.connect (() => Application.get_default ().activate_action ("about", null));
			items.add (about_item);

			if (!environment_is_session_desktop (XdgSessionDesktop.PANTHEON)) {
				items.add (new Gtk.SeparatorMenuItem ());

				var quit_item = DockElement.create_menu_item ("退出(_Q)", "application-exit", true);
				quit_item.activate.connect (() => Application.get_default ().activate_action ("quit", null));
				items.add (quit_item);
			}
		}

		public override Gee.ArrayList<Gtk.MenuItem> get_menu_items ()
		{
			var items = new Gee.ArrayList<Gtk.MenuItem> ();
			append_full_system_menu (get_dock (), items);
			return items;
		}
	}
}
