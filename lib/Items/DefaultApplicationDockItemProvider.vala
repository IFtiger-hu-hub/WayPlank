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
	public class DefaultApplicationDockItemProvider : ApplicationDockItemProvider
	{
		public DockPreferences Prefs { get; construct; }
		public bool docklets_expanded { get; protected set; default = false; }
		uint docklets_collapse_timer_id = 0U;

		public static bool is_docklet_element (DockElement el)
		{
			if (el is TrashDockItem || el is SeparatorDockItem)
				return false;
			if (el is PlankDockItem)
				return true;
			var item = el as DockItem;
			if (item != null && item.Prefs != null && item.Prefs.Launcher != null)
				return item.Prefs.Launcher.has_prefix ("docklet://");
			return false;
		}

		public DefaultApplicationDockItemProvider (DockPreferences prefs, File launchers_dir)
		{
			Object (Prefs : prefs, LaunchersDir : launchers_dir);
		}

		construct
		{
			Prefs.notify["CurrentWorkspaceOnly"].connect (handle_setting_changed);
			Prefs.notify["PinnedOnly"].connect (handle_pinned_only_changed);
			Prefs.notify["CategorizeItems"].connect (handle_categorize_items_changed);
			Prefs.notify["AccordionDocklets"].connect (handle_accordion_docklets_changed);
		}

		~DefaultApplicationDockItemProvider ()
		{
			cancel_collapse_timer ();
			Prefs.notify["CurrentWorkspaceOnly"].disconnect (handle_setting_changed);
			Prefs.notify["PinnedOnly"].disconnect (handle_pinned_only_changed);
			Prefs.notify["CategorizeItems"].disconnect (handle_categorize_items_changed);
			Prefs.notify["AccordionDocklets"].disconnect (handle_accordion_docklets_changed);
		}

		void handle_accordion_docklets_changed ()
		{
			cancel_collapse_timer ();
			docklets_expanded = false;
			foreach (var element in internal_elements) {
				element.RemoveTime = 0;
			}
			refresh_separators ();
		}

		public void expand_docklets ()
		{
			cancel_collapse_timer ();
			if (docklets_expanded)
				return;
			if (!Prefs.CategorizeItems || !Prefs.AccordionDocklets)
				return;
			docklets_expanded = true;
			foreach (var item in internal_elements) {
				if (is_docklet_element (item)) {
					item.AddTime = 0;
					item.RemoveTime = 0;
				}
			}
			refresh_separators ();
		}

		public void cancel_collapse_timer ()
		{
			if (docklets_collapse_timer_id != 0U) {
				Source.remove (docklets_collapse_timer_id);
				docklets_collapse_timer_id = 0U;
			}
		}

		public void schedule_collapse_docklets (uint delay_ms = 300U)
		{
			unowned DockController? dock = get_dock ();
			if (dock != null && (dock.drag_manager.InternalDragActive || dock.drag_manager.ExternalDragActive))
				return;
			if (!docklets_expanded)
				return;
			if (docklets_collapse_timer_id != 0U)
				return;
			docklets_collapse_timer_id = Timeout.add (delay_ms, () => {
				docklets_collapse_timer_id = 0U;
				unowned DockController? d = get_dock ();
				if (d != null && (d.drag_manager.InternalDragActive || d.drag_manager.ExternalDragActive))
					return Source.REMOVE;
				if (docklets_expanded) {
					docklets_expanded = false;
					refresh_separators ();
				}
				return Source.REMOVE;
			});
		}

		void handle_categorize_items_changed ()
		{
			cancel_collapse_timer ();
			docklets_expanded = false;
			foreach (var element in internal_elements) {
				element.RemoveTime = 0;
			}
			if (!Prefs.CategorizeItems) {
				save_current_order_to (false);
				restore_order_from (Prefs.FreeDockItems);
			} else {
				save_current_order_to (true);
				if (Prefs.CategorizedDockItems.length > 0) {
					restore_order_from (Prefs.CategorizedDockItems);
				}
			}
			update_visible_elements ();

			unowned DockController? dock = get_dock ();
			// CRITICAL RENDERER READY GUARD:
			// During initial startup, add_default_provider () runs before renderer.initialize ().
			// If a category setting triggers this callback early, dock.renderer or its theme may be null.
			// Guarding against null prevents assertion failures (plank_dock_renderer_reset_buffers: assertion 'self != NULL').
			if (dock != null && dock.renderer != null && dock.renderer.theme != null) {
				dock.update_items ();
				dock.position_manager.update (dock.renderer.theme);
				dock.renderer.reset_buffers ();
				dock.renderer.animated_draw ();
				dock.schedule_serialize_item_positions ();
			}
		}

		void save_current_order_to (bool is_free)
		{
			var item_list = new Gee.ArrayList<string> ();
			foreach (var element in internal_elements) {
				unowned DockItem? item = (element as DockItem);
				if (item != null && !(item is TransientDockItem) && !(item is SeparatorDockItem) && item.DockItemFilename.length > 0)
					item_list.add (item.DockItemFilename);
			}
			if (item_list.size == 0)
				return;
			if (is_free)
				Prefs.FreeDockItems = item_list.to_array ();
			else
				Prefs.CategorizedDockItems = item_list.to_array ();
		}

		void restore_order_from (string[] target_items)
		{
			if (target_items == null || target_items.length == 0)
				return;

			var ordered_elements = new Gee.ArrayList<DockElement> ();
			var remaining_elements = new Gee.ArrayList<DockElement> ();
			TrashDockItem? trash_item = null;
			var transient_items = new Gee.ArrayList<DockElement> ();

			for (int i = 0; i < internal_elements.size; i++) {
				var el = internal_elements.get (i);
				if (el is SeparatorDockItem) {
					continue;
				} else if (el is TrashDockItem) {
					trash_item = (TrashDockItem) el;
				} else if (el is TransientDockItem) {
					transient_items.add (el);
				} else {
					remaining_elements.add (el);
				}
			}

			foreach (var fn in target_items) {
				for (int i = 0; i < remaining_elements.size; i++) {
					var el = remaining_elements.get (i);
					unowned DockItem? item = el as DockItem;
					if (item != null && item.DockItemFilename == fn) {
						ordered_elements.add (el);
						remaining_elements.remove_at (i);
						break;
					}
				}
			}

			foreach (var el in remaining_elements) {
				ordered_elements.add (el);
			}

			foreach (var el in transient_items) {
				ordered_elements.add (el);
			}

			if (trash_item != null) {
				ordered_elements.add (trash_item);
			}

			internal_elements.clear ();
			foreach (var el in ordered_elements) {
				internal_elements.add (el);
			}
		}

		bool updating_visible_elements = false;

		protected override void update_visible_elements ()
		{
			foreach (var item in internal_elements) {
				item.IsAttached = !(Prefs.PinnedOnly && item is TransientDockItem);
				if (item.IsAttached)
					item.RemoveTime = 0;
			}
			
			if (!updating_visible_elements) {
				updating_visible_elements = true;
				maintain_separator ();
				updating_visible_elements = false;
			}

			unowned DockController? dock = get_dock ();
			bool drag_active = (dock != null && (dock.drag_manager.InternalDragActive || dock.drag_manager.ExternalDragActive));
			if (drag_active) {
				docklets_expanded = true;
			}

			if (Prefs.CategorizeItems && Prefs.AccordionDocklets && !docklets_expanded && !drag_active) {
				bool seen_first = false;
				foreach (var element in internal_elements) {
					if (is_docklet_element (element)) {
						if (!seen_first) {
							seen_first = true;
							element.IsAttached = true;
						} else {
							element.IsAttached = false;
						}
						element.AddTime = 0;
						element.RemoveTime = 0;
					}
				}
			}

			base.update_visible_elements ();
		}

		public void refresh_separators ()
		{
			update_visible_elements ();
			unowned DockController? dock = get_dock ();
			if (dock != null) {
				dock.update_items ();
				dock.renderer.animated_draw ();
			}
		}
		
		/**
		 * Keeps a real SeparatorDockItem present exactly between the pinned and
		 * temporary items, so its layout/animation is handled by the normal
		 * per-item positioning instead of derived overlay coordinates.
		/**
		 * Maintains clean grouping and dynamic separators:
		 * - Pinned items (apps, folders, docklets) are grouped on the left.
		 * - Transient (running unpinned) items are grouped in the middle.
		 * - TrashDockItem is permanently anchored at the far right.
		 * - Dynamic separators:
		 *     * With Trash:
		 *         - If transient items exist: 2 separators [Pinned] | [Transient] | [Trash]
		 *         - If no transient items:    1 separator  [Pinned] | [Trash]
		 *     * Without Trash:
		 *         - If transient items exist: 1 separator  [Pinned] | [Transient]
		 *         - If no transient items:    0 separators [Pinned]
		 */
		void maintain_separator ()
		{
			unowned DockController? dock = get_dock ();
			unowned DockItem? dragging_item = (dock != null && dock.drag_manager.InternalDragActive)
				? dock.drag_manager.DragItem : null;
			if (dragging_item != null)
				return;

			// Step 1: Collect existing separators and identify Trash item
			var existing_separators = new Gee.ArrayList<SeparatorDockItem> ();
			TrashDockItem? trash_item = null;

			for (int i = 0; i < internal_elements.size; i++) {
				var el = internal_elements.get (i);
				if (el is SeparatorDockItem) {
					existing_separators.add ((SeparatorDockItem) el);
				} else if (el is TrashDockItem) {
					trash_item = (TrashDockItem) el;
				}
			}

			// Step 2: Keep existing separators connected so they remain stable and flicker-free

			// Step 3: Anchor Trash permanently at the very end of internal_elements
			if (trash_item != null && dragging_item == null) {
				int trash_idx = internal_elements.index_of (trash_item);
				if (trash_idx >= 0 && trash_idx != internal_elements.size - 1) {
					move_element (internal_elements, trash_idx, internal_elements.size - 1);
				}
			}

			// Step 4: Categorized Grouping or Classic Plank Arrangement
			if (Prefs.CategorizeItems) {
				var orphan_transients = new Gee.ArrayList<TransientDockItem> ();
				var folders = new Gee.ArrayList<DockElement> ();
				var pinned_apps = new Gee.ArrayList<DockElement> ();
				var docklets = new Gee.ArrayList<DockElement> ();
				var transients = new Gee.ArrayList<DockElement> ();

				for (int i = 0; i < internal_elements.size; i++) {
					var el = internal_elements.get (i);
					if (el is TrashDockItem || el is SeparatorDockItem)
						continue;
					if (el is TransientDockItem) {
						var trans = (TransientDockItem) el;
						var win_count = WindowManager.get_default ().window_count_for_app (trans.Launcher);
						if (win_count <= 0) {
							orphan_transients.add (trans);
							continue;
						}
						if (!Prefs.PinnedOnly)
							transients.add (el);
					} else if (el is FileDockItem) {
						folders.add (el);
					} else if (is_docklet_element (el)) {
						docklets.add (el);
					} else {
						pinned_apps.add (el);
					}
				}

				foreach (var orphan in orphan_transients) {
					disconnect_element (orphan);
					internal_elements.remove (orphan);
					orphan.Container = null;
				}

				// Build ordered non-empty category groups:
				// Fixed sequence: Folders -> Docklets -> Pinned Apps -> Unpinned Transients -> Trash
				var groups = new Gee.ArrayList<Gee.ArrayList<DockElement>> ();

				if (folders.size > 0)
					groups.add (folders);

				if (docklets.size > 0)
					groups.add (docklets);

				if (pinned_apps.size > 0)
					groups.add (pinned_apps);

				if (transients.size > 0)
					groups.add (transients);

				if (trash_item != null) {
					var trash_group = new Gee.ArrayList<DockElement> ();
					trash_group.add (trash_item);
					groups.add (trash_group);
				}

				// Rebuild internal_elements with dynamic separators between adjacent non-empty groups
				internal_elements.clear ();
				int sep_pool_idx = 0;
				for (int g = 0; g < groups.size; g++) {
					if (g > 0) {
						SeparatorDockItem sep;
						if (sep_pool_idx < existing_separators.size) {
							sep = existing_separators.get (sep_pool_idx++);
						} else {
							sep = new SeparatorDockItem ();
							sep.Container = this;
							connect_element (sep);
						}
						sep.AddTime = 0;
						sep.RemoveTime = 0;
						internal_elements.add (sep);
					}
					foreach (var item in groups.get (g)) {
						internal_elements.add (item);
					}
				}

				// Clean up any remaining unused separators in the pool to prevent leaks
				while (sep_pool_idx < existing_separators.size) {
					var unused_sep = existing_separators.get (sep_pool_idx++);
					disconnect_element (unused_sep);
					unused_sep.Container = null;
				}
				return;
			}

			// Step 4b (Classic): Ensure all pinned items precede transient items
			if (dragging_item == null) {
				int first_transient = -1;
				for (int i = 0; i < internal_elements.size; i++) {
					var el = internal_elements.get (i);
					if (el is TransientDockItem) {
						if (first_transient < 0)
							first_transient = i;
					} else if (first_transient >= 0 && !(el is TrashDockItem)) {
						move_element (internal_elements, i, first_transient);
						first_transient++;
					}
				}
			}

			// Step 5: Count items and prune orphan transient items with no windows
			int pinned_count = 0;
			int transient_count = 0;
			int first_transient_idx = -1;
			int trash_idx = -1;

			var orphan_transients = new Gee.ArrayList<TransientDockItem> ();
			for (int i = 0; i < internal_elements.size; i++) {
				var el = internal_elements.get (i);
				if (el is TrashDockItem) {
					trash_idx = i;
				} else if (el is TransientDockItem) {
					var trans = (TransientDockItem) el;
					var win_count = WindowManager.get_default ().window_count_for_app (trans.Launcher);
					if (win_count <= 0 && dragging_item == null) {
						orphan_transients.add (trans);
						continue;
					}
					if (!Prefs.PinnedOnly) {
						transient_count++;
						if (first_transient_idx < 0)
							first_transient_idx = i;
					}
				} else {
					pinned_count++;
				}
			}

			foreach (var orphan in orphan_transients) {
				disconnect_element (orphan);
				internal_elements.remove (orphan);
				orphan.Container = null;
			}
			// Step 6: Temporarily remove existing separators from internal_elements without disconnecting
			for (int i = internal_elements.size - 1; i >= 0; i--) {
				if (internal_elements.get (i) is SeparatorDockItem)
					internal_elements.remove_at (i);
			}

			if (trash_item != null)
				trash_idx = internal_elements.index_of (trash_item);

			// Step 7: Determine separator insertion positions
			// Insert from highest index to lowest so earlier target indices remain valid
			var insert_positions = new Gee.ArrayList<int> ();

			if (trash_item != null) {
				if (transient_count > 0 && pinned_count > 0) {
					// 2 separators: [Pinned] | [Transient] | [Trash]
					insert_positions.add (trash_idx);
					insert_positions.add (first_transient_idx);
				} else if (transient_count > 0 && pinned_count == 0) {
					// 1 separator: [Transient] | [Trash]
					insert_positions.add (trash_idx);
				} else if (pinned_count > 0) {
					// 1 separator: [Pinned] | [Trash]
					insert_positions.add (trash_idx);
				}
			} else {
				if (transient_count > 0 && pinned_count > 0) {
					// 1 separator: [Pinned] | [Transient]
					insert_positions.add (first_transient_idx);
				}
			}

			// Step 8: Insert separators at target positions (reusing pool or instantiating new)
			int sep_pool_idx = 0;
			foreach (int pos in insert_positions) {
				if (pos < 0 || pos > internal_elements.size)
					continue;
				SeparatorDockItem sep;
				if (sep_pool_idx < existing_separators.size) {
					sep = existing_separators.get (sep_pool_idx++);
				} else {
					sep = new SeparatorDockItem ();
					sep.Container = this;
					connect_element (sep);
				}
				sep.AddTime = 0;
				sep.RemoveTime = 0;
				internal_elements.insert (pos, sep);
			}

			// Clean up any remaining unused separators in the pool to prevent leaks
			while (sep_pool_idx < existing_separators.size) {
				var unused_sep = existing_separators.get (sep_pool_idx++);
				disconnect_element (unused_sep);
				unused_sep.Container = null;
			}
		}

		public override void prepare ()
		{
			var favs = new Gee.ArrayList<string> ();

			foreach (var element in internal_elements) {
				unowned ApplicationDockItem? item = (element as ApplicationDockItem);
				if (item != null)
					favs.add (item.Launcher);
			}

			Matcher.get_default ().set_favorites (favs);
		}

		protected override void app_opened (string app_id)
		{
			if (WindowControl.has_state ())
				return;

			unowned ApplicationDockItem? found = item_for_application_id (app_id);
			if (found != null) {
				return;
			}

			// Find the corresponding .desktop file in the system to create the icon on the fly
			var desktop_file = desktop_file_for_application_id (app_id);
			if (desktop_file != null) {
				var new_item = new TransientDockItem.with_launcher (desktop_file.get_uri ());
				add (new_item);
			}
		}

		private File? desktop_file_for_application_id (string app_id)
		{
			foreach (var folder in Paths.DataDirFolders) {
				var applications_folder = folder.get_child ("applications");
				if (!applications_folder.query_exists ())
					continue;

				var desktop_file = applications_folder.get_child (app_id);
				if (desktop_file.query_exists ())
					return desktop_file;
			}
			return null;
		}

		void handle_setting_changed ()
		{
			update_visible_elements ();
		}

		void handle_pinned_only_changed ()
		{
			update_visible_elements ();
		}

		protected override void connect_element (DockElement element)
		{
			base.connect_element (element);

			unowned ApplicationDockItem? appitem = (element as ApplicationDockItem);
			if (appitem != null) {
				appitem.pin_launcher.connect (pin_item);
			}
		}

		protected override void disconnect_element (DockElement element)
		{
			base.disconnect_element (element);

			unowned ApplicationDockItem? appitem = (element as ApplicationDockItem);
			if (appitem != null) {
				appitem.pin_launcher.disconnect (pin_item);
			}
		}

		public void pin_item (DockItem item)
		{
			if (!internal_elements.contains (item))
				return;

			unowned ApplicationDockItem? app_item = (item as ApplicationDockItem);
			if (app_item == null)
				return;

			delay_items_monitor ();

			if (item is TransientDockItem) {
				var dockitem_file = Factory.item_factory.make_dock_item (item.Launcher, LaunchersDir);
				if (dockitem_file != null) {
					var new_item = new ApplicationDockItem.with_dockitem_file (dockitem_file);
					item.copy_values_to (new_item);
					replace (new_item, item);
				}
			} else {
				var launcher_uri = item.Launcher;
				var win_count = WindowManager.get_default ().window_count_for_app (item.Launcher);
				item.delete ();
				
				// Re-add as a temporary item only if the app has active open windows
				if (win_count > 0) {
					var new_item = new TransientDockItem.with_launcher (launcher_uri);
					add (new_item);
				}
			}

			resume_items_monitor ();
		}
	}
}
