//
//  Copyright (C) 2011-2012 Robert Dyer, Michal Hruby, Rico Tzschichholz
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
	public const string G_RESOURCE_PATH = "/net/launchpad/plank";
	
	/**
	 * A controller class for managing a single dock.
	 *
	 * All needed controlling parts will be created and initialized.
	 */
	public class DockController : DockContainer
	{
		public string name { get; construct; }
		public File config_folder { get; construct; }
		public File launchers_folder { get; private set; }
		
		public DockPreferences prefs { get; construct; }
		
		public DragManager drag_manager { get; protected set; }
		public HideManager hide_manager { get; protected set; }
		public PositionManager position_manager { get; protected set; }
		public DockRenderer renderer { get; protected set; }
		public DockWindow window { get; protected set; }
		public HoverWindow hover { get; protected set; }
		public FolderMenuWindow folder_menu { get; protected set; }
		public WindowCardsWindow window_cards { get; protected set; }
		public string last_explicit_monitor { get; set; default = ""; }
		
		public DockItemProvider? default_provider { get; private set; }
		public unowned DefaultApplicationDockItemProvider? app_provider {
			get { return default_provider as DefaultApplicationDockItemProvider; }
		}
		
		DBusManager dbus_manager;
		Gee.ArrayList<unowned DockItem> visible_items;
		Gee.ArrayList<unowned DockItem> items;
		DockItem? dock_itself_item;
		uint serialize_item_positions_timer_id = 0U;
		uint states_draw_timer_id = 0U;
		bool is_initialized = false;

		public enum WindowMinimizeTransition
		{
			NONE,
			MINIMIZING,
			RESTORING
		}

		Gee.HashMap<string, WindowMinimizeTransition> minimize_transitions;
		Gee.HashMap<string, uint> transition_timer_ids;
		Gee.HashMap<string, Gdk.Rectangle?> last_minimized_regions;
		Gee.HashSet<string> last_known_minimized_uuids;
		bool minimize_transition_initialized = false;
		
		/**
		 * List of all items on this dock
		 */
		public Gee.ArrayList<unowned DockItem> Items {
			get {
				return items;
			}
		}
		
		/**
		 * Ordered list of all visible items on this dock
		 */
		public Gee.ArrayList<unowned DockItem> VisibleItems {
			get {
				return visible_items;
			}
		}
		
		/**
		 * Create a new DockController which manages a single dock
		 *
		 * @param config_folder the base-folder to load settings from and save them to
		 */
		public DockController (string dock_name, File config_folder)
		{
			// Make sure our config-directory exists
			Paths.ensure_directory_exists (config_folder);
			
			debug ("Create dock '%s' (config_folder = %s)", dock_name, config_folder.get_path ());
			
			Object (name : dock_name, config_folder : config_folder, prefs : new DockPreferences (dock_name));
		}
		
		construct
		{
			launchers_folder = config_folder.get_child ("launchers");
			Factory.item_factory.launchers_dir = launchers_folder;
			
			items = new Gee.ArrayList<unowned DockItem> ();
			visible_items = new Gee.ArrayList<unowned DockItem> ();

			minimize_transitions = new Gee.HashMap<string, WindowMinimizeTransition> ();
			transition_timer_ids = new Gee.HashMap<string, uint> ();
			last_minimized_regions = new Gee.HashMap<string, Gdk.Rectangle?> ();
			last_known_minimized_uuids = new Gee.HashSet<string> ();
			
			prefs.notify["Position"].connect (update_visible_elements);
			prefs.notify["ShowDockItem"].connect (update_show_dock_item);
			if (prefs.Monitor != "")
				last_explicit_monitor = prefs.Monitor;
			prefs.notify["Monitor"].connect (update_explicit_monitor);
			
			dbus_manager = new DBusManager (this);
			
			position_manager = new PositionManager (this);
			drag_manager = new DragManager (this);
			hide_manager = new HideManager (this);
			window = new DockWindow (this);
			hover = new HoverWindow ();
			folder_menu = new FolderMenuWindow (this);
			window_cards = new WindowCardsWindow (this);
			renderer = new DockRenderer (this, window);
		}
		
		void update_explicit_monitor ()
		{
			if (prefs.Monitor != "")
				last_explicit_monitor = prefs.Monitor;
		}

		~DockController ()
		{
			folder_menu.destroy ();
			window_cards.destroy ();
			prefs.notify["Monitor"].disconnect (update_explicit_monitor);
			prefs.notify["Position"].disconnect (update_visible_elements);
			prefs.notify["ShowDockItem"].disconnect (update_show_dock_item);
			
			if (is_initialized) {
				positions_changed.disconnect (handle_positions_changed);
				states_changed.disconnect (handle_states_changed);
				elements_changed.disconnect (handle_elements_changed);
			}
			
			if (serialize_item_positions_timer_id > 0U) {
				Source.remove (serialize_item_positions_timer_id);
				serialize_item_positions_timer_id = 0U;
			}
			serialize_item_positions ();

			foreach (var timer_id in transition_timer_ids.values) {
				if (timer_id > 0U)
					Source.remove (timer_id);
			}
			transition_timer_ids.clear ();

			items.clear ();
			visible_items.clear ();

			if (hover != null)
				hover.destroy ();
			if (window != null)
				window.destroy ();

			KWinPlasmaWindow.cleanup ();
		}
		
		/**
		 * Initialize this controller.
		 * Call this when added at least one DockItemProvider otherwise the
		 * {@link Plank.DefaultApplicationDockItemProvider} will be added by default.
		 */
		public void initialize ()
		{
			if (internal_elements.size <= 0)
				add_default_provider ();
			
			update_show_dock_item ();
			update_items ();
			
			AddTime = GLib.get_monotonic_time ();
			
			positions_changed.connect (handle_positions_changed);
			states_changed.connect (handle_states_changed);
			elements_changed.connect (handle_elements_changed);
			is_initialized = true;
			
			position_manager.initialize ();
			drag_manager.initialize ();
			hide_manager.initialize ();
			renderer.initialize ();
			hide_manager.refresh_visibility ();

			// Update the calculated dimensions and map the window on Wayland
			position_manager.update (renderer.theme);
			window.update_size_and_position ();
			window.show_all ();
			if (GtkLayerShell.is_supported ())
				window.present ();
			window.queue_draw ();

			KWinPlasmaWindow.init (window);
			sync_minimized_geometries ();
		}

		public void sync_minimized_geometries ()
		{
			if (!is_initialized || window == null || !window.get_realized () || !window.get_mapped () || !window.get_visible ())
				return;

			var window_manager = WindowManager.get_default ();
			var windows = WindowControl.get_windows ();
			if (windows.size == 0)
				return;

			// 更新最小化状态机并处理过度计时
			update_window_minimize_transitions (windows);

			var specific_uuids = new Gee.HashSet<string> ();

			// 1. 处于 RESTORING 状态的窗口：强制保持在右侧卡片记录的位置，供展开动画使用
			foreach (var entry in minimize_transitions.entries) {
				if (entry.value == WindowMinimizeTransition.RESTORING) {
					var uuid = entry.key;
					if (last_minimized_regions.has_key (uuid)) {
						var rect = last_minimized_regions[uuid];
						if (rect != null && rect.width > 0 && rect.height > 0) {
							KWinPlasmaWindow.set_window_minimized_geometry (uuid, rect.x, rect.y, rect.width, rect.height);
							specific_uuids.add (uuid);
						}
					}
				}
			}

			// 2. 右侧已有的 MinimizedWindowDockItem
			foreach (unowned DockItem item in VisibleItems) {
				if (item is MinimizedWindowDockItem) {
					var min_item = (MinimizedWindowDockItem) item;
					var draw_val = position_manager.get_draw_value_for_item (min_item);
					var rect = draw_val.draw_region;
					if (rect.width > 0 && rect.height > 0) {
						last_minimized_regions[min_item.WindowId] = rect;

						// 处于 MINIMIZING 状态的窗口：动画正在吸入左侧应用主图标，禁止提前切到右边！
						if (minimize_transitions.has_key (min_item.WindowId) &&
						    minimize_transitions[min_item.WindowId] == WindowMinimizeTransition.MINIMIZING) {
							continue;
						}

						KWinPlasmaWindow.set_window_minimized_geometry (min_item.WindowId, rect.x, rect.y, rect.width, rect.height);
						specific_uuids.add (min_item.WindowId);
					}
				}
			}

			// 3. 左侧主图标：将其余窗口（包括处于 MINIMIZING 状态的窗口）设为左侧主图标坐标
			foreach (unowned DockItem item in VisibleItems) {
				if (item is ApplicationDockItem) {
					var app_item = (ApplicationDockItem) item;
					var matched_windows = window_manager.matching_windows (app_item.Launcher);
					if (matched_windows.size == 0)
						continue;

					var draw_val = position_manager.get_draw_value_for_item (app_item);
					var rect = draw_val.draw_region;
					if (rect.width <= 0 || rect.height <= 0)
						continue;

					foreach (var win in matched_windows) {
						if (!specific_uuids.contains (win.Id)) {
							// 关键防护：如果窗口不在当前工作区，绝对不要向其发送当前工作区的 Dock 几何位置！
							if (!win.CurrentDesktop)
								continue;
							KWinPlasmaWindow.set_window_minimized_geometry (win.Id, rect.x, rect.y, rect.width, rect.height);
						}
					}
				}
			}

			// 收集当前已知活动的窗口 UUID，在主循环中安全修剪已关闭窗口的代理
			string[] active_uuids = new string[windows.size];
			for (int i = 0; i < windows.size; i++) {
				active_uuids[i] = windows[i].Id;
			}
			KWinPlasmaWindow.prune_window_proxies (active_uuids);
		}

		void update_window_minimize_transitions (Gee.ArrayList<WindowInfo> windows)
		{
			var current_min_uuids = new Gee.HashSet<string> ();
			var active_window_uuids = new Gee.HashSet<string> ();

			foreach (var win in windows) {
				active_window_uuids.add (win.Id);
				if (win.Minimized) {
					current_min_uuids.add (win.Id);
				}
			}

			if (!minimize_transition_initialized) {
				minimize_transition_initialized = true;
				last_known_minimized_uuids.add_all (current_min_uuids);
				return;
			}

			// 检测从未最小化变为最小化 (Minimize): 持续 450ms 保持在左侧应用图标
			foreach (var uuid in current_min_uuids) {
				if (!last_known_minimized_uuids.contains (uuid)) {
					start_minimize_transition (uuid, WindowMinimizeTransition.MINIMIZING, 450);
				}
			}

			// 检测从已最小化变为恢复 (Restore): 持续 450ms 保持在右侧卡片展开
			foreach (var uuid in last_known_minimized_uuids) {
				if (!current_min_uuids.contains (uuid) && active_window_uuids.contains (uuid)) {
					start_minimize_transition (uuid, WindowMinimizeTransition.RESTORING, 450);
				}
			}

			// 清理已销毁窗口
			foreach (var uuid in last_known_minimized_uuids.to_array ()) {
				if (!active_window_uuids.contains (uuid)) {
					cancel_minimize_transition (uuid);
					last_minimized_regions.unset (uuid);
				}
			}

			last_known_minimized_uuids.clear ();
			last_known_minimized_uuids.add_all (current_min_uuids);
		}

		void start_minimize_transition (string uuid, WindowMinimizeTransition state, uint duration_ms)
		{
			cancel_minimize_transition (uuid);
			minimize_transitions[uuid] = state;

			transition_timer_ids[uuid] = Timeout.add (duration_ms, () => {
				transition_timer_ids.unset (uuid);
				minimize_transitions.unset (uuid);
				sync_minimized_geometries ();
				return Source.REMOVE;
			});
		}

		void cancel_minimize_transition (string uuid)
		{
			if (transition_timer_ids.has_key (uuid)) {
				Source.remove (transition_timer_ids[uuid]);
				transition_timer_ids.unset (uuid);
			}
			minimize_transitions.unset (uuid);
		}
		
		/**
		 * Add the default provider which is an instance of
		 * {@link Plank.DefaultApplicationDockItemProvider}
		 */
		public void add_default_provider ()
		{
			if (default_provider != null)
				return;
			
			Logger.verbose ("DockController.add_default_provider ()");
			default_provider = create_default_provider ();
			
			string[] target_items = prefs.DockItems;
			if (prefs.CategorizeItems && prefs.CategorizedDockItems != null && prefs.CategorizedDockItems.length > 0) {
				target_items = prefs.CategorizedDockItems;
			} else if (!prefs.CategorizeItems && prefs.FreeDockItems != null && prefs.FreeDockItems.length > 0) {
				target_items = prefs.FreeDockItems;
			}
			if (target_items.length == 0 && prefs.DockItems != null && prefs.DockItems.length > 0) {
				target_items = prefs.DockItems;
			}
			var elements = Factory.item_factory.load_elements (launchers_folder, target_items);

			foreach (var element in elements)
				if (element is DockItem)
					default_provider.add (element);

			unowned DefaultApplicationDockItemProvider? def_prov = default_provider as DefaultApplicationDockItemProvider;
			if (def_prov != null) {
				def_prov.deduplicate_items ();
				def_prov.ensure_preferences_dockitem ();
				def_prov.deduplicate_items ();
				if (prefs.FreeDockItems == null || prefs.FreeDockItems.length == 0) {
					def_prov.reorder_free_items_by_category ();
				}
			}

			bool has_default_provider = false;
			foreach (var element in elements) {
				if (!has_default_provider && element is DockItem) {
					add (default_provider);
					has_default_provider = true;
				} else if (element is DockItemProvider) {
					add (element);
				}
			}
			if (!has_default_provider)
				add (default_provider);

			schedule_serialize_item_positions ();
		}
		
		DockItemProvider create_default_provider ()
		{
			DockItemProvider provider;
			
			// If we made the default-launcher-directory or it is empty,
			// assume a first run and pre-populate with modern launchers
			bool is_first_run = Paths.ensure_directory_exists (launchers_folder);
			if (!is_first_run) {
				try {
					var enumerator = launchers_folder.enumerate_children (FileAttribute.STANDARD_NAME, 0);
					if (enumerator.next_file (null) == null)
						is_first_run = true;
				} catch { }
			}
			
			if (is_first_run) {
				debug ("First run or empty launchers detected: initializing modern defaults...");
				prefs.CategorizeItems = true;
				prefs.AccordionDocklets = true;
				prefs.ShowDockItem = false;
				Factory.item_factory.make_default_items ();
				debug ("done.");
			}
			
			provider = new DefaultApplicationDockItemProvider (prefs, launchers_folder);
			
			return provider;
		}
		
		void update_show_dock_item ()
		{
			if (prefs.ShowDockItem) {
				if (dock_itself_item == null)
					dock_itself_item = Factory.item_factory.get_item_for_dock ();
				if (!internal_elements.contains (dock_itself_item))
					prepend (dock_itself_item);
			} else if (dock_itself_item != null) {
				if (internal_elements.contains (dock_itself_item))
					remove (dock_itself_item);
				dock_itself_item = null;
			}
		}
		
		protected override void connect_element (DockElement element)
		{
			unowned DockItemProvider? provider = (element as DockItemProvider);
			if (provider == null)
				return;
			
			provider.positions_changed.connect (handle_positions_changed);
			provider.states_changed.connect (handle_states_changed);
			provider.elements_changed.connect (handle_elements_changed);
			
			unowned ApplicationDockItemProvider? app_provider = (provider as ApplicationDockItemProvider);
			if (app_provider != null) {
				Unity.get_default ().add_client (app_provider);
			}
		}
		
		protected override void disconnect_element (DockElement element)
		{
			unowned DockItemProvider? provider = (element as DockItemProvider);
			if (provider == null)
				return;
			
			provider.positions_changed.disconnect (handle_positions_changed);
			provider.states_changed.disconnect (handle_states_changed);
			provider.elements_changed.disconnect (handle_elements_changed);
			
			unowned ApplicationDockItemProvider? app_provider = (provider as ApplicationDockItemProvider);
			if (app_provider != null) {
				Unity.get_default ().remove_client (app_provider);
			}
		}
		
		protected override void update_visible_elements ()
		{
			base.update_visible_elements ();
			
			Logger.verbose ("DockController.update_visible_items ()");
			
			visible_items.clear ();
			
			var current_position = 0;
			update_visible_items_recursive (this, ref current_position);
		}
		
		void update_visible_items_recursive (DockContainer container, ref int current_position)
		{
			var iterator = container.VisibleElements.bidir_list_iterator ();
			
			// Reverse dock-item-order for RTL environments if dock is placed horizontally
			if (Gtk.Widget.get_default_direction () == Gtk.TextDirection.RTL && prefs.is_horizontal_dock ()) {
				iterator.last ();
				do {
					update_visible_items_add_from_iterator (iterator, ref current_position);
				} while (iterator.previous ());
			} else {
				iterator.first ();
				do {
					update_visible_items_add_from_iterator (iterator, ref current_position);
				} while (iterator.next ());
			}
		}
		
		inline void update_visible_items_add_from_iterator (Gee.Iterator<DockElement> iterator, ref int current_position)
		{
			DockElement? element = iterator.get ();
			unowned DockItem? item = null;
			unowned DockContainer? container = null;
			
			container = (element as DockContainer);
			if (container != null) {
				update_visible_items_recursive (container, ref current_position);
				return;
			}

			item = (element as DockItem);
			if (item == null)
				return;
			
			if (item.Position != current_position)
				item.Position = current_position;
			current_position++;
			
			visible_items.add (item);
		}
		
		public void update_items ()
		{
			Logger.verbose ("DockController.update_items ()");
			
			items.clear ();
			
			unowned DockItem? item = null;
			unowned DockContainer? container = null;
			
			foreach (var element in internal_elements) {
				item = (element as DockItem);
				if (item != null) {
					items.add (item);
					continue;
				}
				
				container = (element as DockContainer);
				if (container == null)
					continue;
				
				foreach (var element2 in container.Elements) {
					item = (element2 as DockItem);
					if (item == null)
						continue;
					items.add (item);
				}
			}
		}
		
		void handle_elements_changed (DockContainer container, Gee.List<DockElement> added, Gee.List<DockElement> removed)
		{
			// Schedule added/removed items for special animations
			renderer.animate_items (added);
			renderer.animate_items (removed);
			
			update_visible_elements ();
			update_items ();
			
			if (added.size != removed.size)
				position_manager.update (renderer.theme);
			
			window.update_icon_regions ();
			
			schedule_serialize_item_positions ();

			// FIXME Maybe add a dedicated signal
			if (container != this) {
				var empty = new Gee.ArrayList<DockElement> ();
				elements_changed (empty, empty);
			}
		}
		
		void handle_positions_changed (DockContainer container, Gee.List<unowned DockElement> moved_items)
		{
			update_visible_elements ();
			
			foreach (unowned DockElement item in moved_items) {
				unowned ApplicationDockItem? app_item = (item as ApplicationDockItem);
				if (app_item != null)
					window.update_icon_region (app_item);
			}
			renderer.animated_draw ();

			schedule_serialize_item_positions ();
			sync_minimized_geometries ();
		}
		
		void handle_states_changed (DockContainer container)
		{
			// Coalesce indicator/urgent redraws — many items fire needs_redraw per window tick
			if (states_draw_timer_id == 0U) {
				states_draw_timer_id = Timeout.add (32, () => {
					states_draw_timer_id = 0U;
					renderer.animated_draw ();
					return false;
				});
			}
			sync_minimized_geometries ();
		}

		public void refresh_visible_elements ()
		{
			update_visible_elements ();
			update_items ();
			window.update_icon_regions ();
			renderer.animated_draw ();
		}
		
		public void schedule_serialize_item_positions ()
		{
			if (serialize_item_positions_timer_id > 0U)
				return;

			serialize_item_positions_timer_id = Gdk.threads_add_timeout (ITEM_SERIALIZATION_DELAY, (SourceFunc) serialize_item_positions);
		}

		bool serialize_item_positions ()
		{
			serialize_item_positions_timer_id = 0U;

			var item_list = new Gee.ArrayList<string> ();

			foreach (var element in internal_elements) {
				unowned DockItem? item = (element as DockItem);
				if (item != null) {
					item_list.add (item.DockItemFilename);
					continue;
				}
				unowned DockItemProvider? provider = (element as DockItemProvider);
				if (provider != null) {
					var list = provider.get_dockitem_filenames ();
					foreach (unowned string s in list)
						item_list.add (s);
					continue;
				}
			}

			if (item_list.size == 0)
				return false;

			prefs.DockItems = item_list.to_array ();
			if (!prefs.CategorizeItems) {
				prefs.FreeDockItems = item_list.to_array ();
			} else {
				prefs.CategorizedDockItems = item_list.to_array ();
			}

			return false;
		}

		public void handle_system_resume ()
		{
			message ("DockController '%s': handling system resume / wake-up", name);
			WindowControl.handle_system_resume ();
			window.update_layer_shell_monitor ();
			position_manager.update_dock_position ();
			window.update_size_and_position ();
			renderer.reset_buffers ();
			hide_manager.wake_up ();
			window.show_all ();
			if (GtkLayerShell.is_supported ())
				window.present ();
			renderer.animated_draw ();
		}

		public bool is_interaction_active (Gtk.Window? closing_win = null)
		{
			if (window != null && window.menu_is_visible ())
				return true;
			if (folder_menu != null && folder_menu.get_visible ())
				return true;
			if (window_cards != null && window_cards.get_visible ())
				return true;
			if (drag_manager != null && (drag_manager.InternalDragActive || drag_manager.ExternalDragActive))
				return true;

			if (PreferencesWindow.is_open && (closing_win == null || !(closing_win is PreferencesWindow)))
				return true;
			if (HelpWindow.is_open && (closing_win == null || !(closing_win is HelpWindow)))
				return true;
			if (IconChooserDialog.is_open && (closing_win == null || !(closing_win is IconChooserDialog)))
				return true;
			if (WeatherCityDialog.is_open && (closing_win == null || !(closing_win is WeatherCityDialog)))
				return true;
			if (AbstractMain.is_about_open && (closing_win == null || !(closing_win is Gtk.AboutDialog)))
				return true;
			if (CalendarWindow.is_open () && (closing_win == null || !(closing_win is CalendarWindow)))
				return true;
			if (WeatherWindow.is_open () && (closing_win == null || !(closing_win is WeatherWindow)))
				return true;
			if (SessionWindow.is_open () && (closing_win == null || !(closing_win is SessionWindow)))
				return true;

			return false;
		}

		public void check_collapse_after_interaction (Gtk.Window? closing_win = null)
		{
			if (prefs.CategorizeItems && prefs.AccordionDocklets && app_provider != null) {
				if (hide_manager.Hovered) {
					app_provider.cancel_collapse_timer ();
				} else if (!is_interaction_active (closing_win)) {
					app_provider.cancel_collapse_timer ();
					app_provider.schedule_collapse_docklets (prefs.AccordionDelay);
				}
			}
		}
	}
}
