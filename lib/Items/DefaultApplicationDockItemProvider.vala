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
	public class DefaultApplicationDockItemProvider : ApplicationDockItemProvider
	{
		public DockPreferences Prefs { get; construct; }
		public bool docklets_expanded { get; protected set; default = false; }
		uint docklets_collapse_timer_id = 0U;

		public static bool is_docklet_element (DockElement el)
		{
			if (el is TrashDockItem || el is SeparatorDockItem || el is PlankDockItem)
				return false;
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
			Prefs.notify["SystemMenuAccess"].connect (handle_system_menu_access_changed);
			Prefs.notify["ShowMinimizedPreviews"].connect (handle_show_minimized_previews_changed);
		}

		public void ensure_preferences_dockitem ()
		{
			if (Prefs.SystemMenuAccess == 4) {
				if (item_for_uri ("docklet://preferences") == null) {
					add_item_with_uri ("docklet://preferences");
				}
			} else {
				unowned DockItem? di = item_for_uri ("docklet://preferences");
				if (di != null) {
					disconnect_element (di);
					internal_elements.remove (di);
					di.Container = null;
					di.delete ();
				}
			}
		}

		void handle_system_menu_access_changed ()
		{
			ensure_preferences_dockitem ();
			refresh_separators ();
			update_visible_elements ();
			unowned DockController? dock = get_dock ();
			if (dock != null && dock.renderer != null && dock.renderer.theme != null) {
				dock.refresh_visible_elements ();
				dock.position_manager.update (dock.renderer.theme);
				dock.renderer.reset_buffers ();
				dock.schedule_serialize_item_positions ();
				if (dock.window != null) {
					dock.window.set_input_mask ();
				}
				dock.renderer.animated_draw ();
			}
		}

		public void deduplicate_items ()
		{
			var seen_uris = new Gee.HashSet<string> ();
			var duplicates = new Gee.ArrayList<DockElement> ();
			
			for (int i = 0; i < internal_elements.size; i++) {
				var el = internal_elements.get (i);
				if (el is SeparatorDockItem)
					continue;
				unowned DockItem? item = el as DockItem;
				if (item != null && item.Launcher != null && item.Launcher != "") {
					if (seen_uris.contains (item.Launcher)) {
						duplicates.add (el);
					} else {
						seen_uris.add (item.Launcher);
					}
				}
			}
			
			foreach (var dup in duplicates) {
				warning ("DefaultApplicationDockItemProvider: Removing duplicate element '%s'", dup.Text);
				disconnect_element (dup);
				internal_elements.remove (dup);
				dup.Container = null;
			}
		}

		~DefaultApplicationDockItemProvider ()
		{
			cancel_collapse_timer ();
			Prefs.notify["CurrentWorkspaceOnly"].disconnect (handle_setting_changed);
			Prefs.notify["PinnedOnly"].disconnect (handle_pinned_only_changed);
			Prefs.notify["CategorizeItems"].disconnect (handle_categorize_items_changed);
			Prefs.notify["AccordionDocklets"].disconnect (handle_accordion_docklets_changed);
			Prefs.notify["SystemMenuAccess"].disconnect (handle_system_menu_access_changed);
			Prefs.notify["ShowMinimizedPreviews"].disconnect (handle_show_minimized_previews_changed);
		}

		void handle_show_minimized_previews_changed ()
		{
			sync_compositor_windows ();
			update_visible_elements ();
		}

		void handle_accordion_docklets_changed ()
		{
			cancel_collapse_timer ();
			docklets_expanded = false;
			foreach (var element in internal_elements) {
				element.IsAttached = true;
				element.AddTime = 0;
				element.RemoveTime = 0;
			}
			refresh_separators ();

			unowned DockController? dock = get_dock ();
			if (dock != null && dock.renderer != null && dock.renderer.theme != null) {
				dock.update_items ();
				dock.position_manager.update (dock.renderer.theme);
				dock.renderer.reset_buffers ();
				dock.renderer.animated_draw ();
				dock.schedule_serialize_item_positions ();
				if (dock.window != null) {
					dock.window.set_input_mask ();
				}
			}
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

			unowned DockController? dock = get_dock ();
			if (dock != null && dock.renderer != null && dock.renderer.theme != null) {
				dock.update_items ();
				dock.position_manager.update (dock.renderer.theme);
				dock.renderer.animated_draw ();
				if (dock.window != null) {
					dock.window.set_input_mask ();
				}
			}
		}

		public void cancel_collapse_timer ()
		{
			if (docklets_collapse_timer_id != 0U) {
				Source.remove (docklets_collapse_timer_id);
				docklets_collapse_timer_id = 0U;
			}
		}

		public void schedule_collapse_docklets (uint delay_ms = 0U)
		{
			if (!Prefs.CategorizeItems || !Prefs.AccordionDocklets) {
				cancel_collapse_timer ();
				return;
			}
			unowned DockController? dock = get_dock ();
			if (dock != null && (dock.drag_manager.InternalDragActive || dock.drag_manager.ExternalDragActive))
				return;
			if (dock != null && dock.is_interaction_active ())
				return;
			if (!docklets_expanded)
				return;
			if (docklets_collapse_timer_id != 0U)
				return;
			uint timeout_ms = delay_ms;
			if (timeout_ms == 0U) {
				timeout_ms = (Prefs != null && Prefs.AccordionDelay >= 500U) ? Prefs.AccordionDelay : 1000U;
			}
			docklets_collapse_timer_id = Timeout.add (timeout_ms, () => {
				docklets_collapse_timer_id = 0U;
				if (!Prefs.CategorizeItems || !Prefs.AccordionDocklets) {
					foreach (var element in internal_elements) {
						element.IsAttached = true;
						element.AddTime = 0;
						element.RemoveTime = 0;
					}
					return Source.REMOVE;
				}
				unowned DockController? d = get_dock ();
				if (d != null && (d.drag_manager.InternalDragActive || d.drag_manager.ExternalDragActive))
					return Source.REMOVE;
				if (d != null && d.is_interaction_active ())
					return Source.REMOVE;
				if (d != null && d.hide_manager.Hovered)
					return Source.REMOVE;
				if (docklets_expanded) {
					docklets_expanded = false;
					refresh_separators ();
					if (d != null && d.renderer != null && d.renderer.theme != null) {
						d.update_items ();
						d.position_manager.update (d.renderer.theme);
						d.renderer.animated_draw ();
						if (d.window != null) {
							d.window.set_input_mask ();
						}
					}
				}
				return Source.REMOVE;
			});
		}

		void handle_categorize_items_changed ()
		{
			cancel_collapse_timer ();
			docklets_expanded = false;
			deduplicate_items ();
			foreach (var element in internal_elements) {
				element.IsAttached = true;
				element.AddTime = 0;
				element.RemoveTime = 0;
			}
			if (!Prefs.CategorizeItems) {
				if (Prefs.SystemMenuAccess == 1 || Prefs.SystemMenuAccess == 2) {
					Prefs.SystemMenuAccess = 3;
				}
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
				dock.refresh_visible_elements ();
				dock.position_manager.update (dock.renderer.theme);
				dock.renderer.reset_buffers ();
				dock.schedule_serialize_item_positions ();
				if (dock.window != null) {
					dock.window.set_input_mask ();
				}
				dock.renderer.animated_draw ();
			}
		}

		void save_current_order_to (bool is_free)
		{
			var item_list = new Gee.ArrayList<string> ();
			var seen = new Gee.HashSet<string> ();
			foreach (var element in internal_elements) {
				unowned DockItem? item = (element as DockItem);
				if (item != null && !(item is TransientDockItem) && item.DockItemFilename.length > 0) {
					if (!seen.contains (item.DockItemFilename)) {
						seen.add (item.DockItemFilename);
						item_list.add (item.DockItemFilename);
					}
				}
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
					if (((SeparatorDockItem) el).is_user_separator ())
						remaining_elements.add (el);
					continue;
				} else if (el is TrashDockItem) {
					trash_item = (TrashDockItem) el;
				} else if (el is TransientDockItem) {
					transient_items.add (el);
				} else {
					remaining_elements.add (el);
				}
			}

			var seen_targets = new Gee.HashSet<string> ();
			foreach (var fn in target_items) {
				if (seen_targets.contains (fn))
					continue;
				seen_targets.add (fn);
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

			var rem_folders = new Gee.ArrayList<DockElement> ();
			var rem_docklets = new Gee.ArrayList<DockElement> ();
			var rem_apps = new Gee.ArrayList<DockElement> ();
			foreach (var el in remaining_elements) {
				if (el is FileDockItem)
					rem_folders.add (el);
				else if (is_docklet_element (el))
					rem_docklets.add (el);
				else
					rem_apps.add (el);
			}
			foreach (var el in rem_folders) ordered_elements.add (el);
			foreach (var el in rem_docklets) ordered_elements.add (el);
			foreach (var el in rem_apps) ordered_elements.add (el);

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

		Gee.ArrayList<DockElement> sort_bucket_by_target (Gee.ArrayList<DockElement> bucket, string[] targets)
		{
			var result = new Gee.ArrayList<DockElement> ();
			foreach (var fn in targets) {
				for (int i = 0; i < bucket.size; i++) {
					var el = bucket.get (i);
					unowned DockItem? item = el as DockItem;
					if (item != null && item.DockItemFilename == fn) {
						result.add (el);
						bucket.remove_at (i);
						break;
					}
				}
			}
			foreach (var el in bucket) {
				result.add (el);
			}
			return result;
		}

		public void reorder_free_items_by_category ()
		{
			cancel_collapse_timer ();
			docklets_expanded = false;
			deduplicate_items ();

			var folders = new Gee.ArrayList<DockElement> ();
			var docklets = new Gee.ArrayList<DockElement> ();
			DockElement? preferences_docklet = null;
			var pinned_apps = new Gee.ArrayList<DockElement> ();
			var transients = new Gee.ArrayList<DockElement> ();
			TrashDockItem? trash_item = null;

			var pending_user_seps = new Gee.ArrayList<DockElement> ();
			for (int i = 0; i < internal_elements.size; i++) {
				var el = internal_elements.get (i);
				if (el is SeparatorDockItem) {
					if (((SeparatorDockItem) el).is_user_separator ())
						pending_user_seps.add (el);
					continue;
				}
				if (el is TrashDockItem) {
					foreach (var sep in pending_user_seps)
						pinned_apps.add (sep);
					pending_user_seps.clear ();
					trash_item = (TrashDockItem) el;
				} else if (el is TransientDockItem) {
					foreach (var sep in pending_user_seps)
						pinned_apps.add (sep);
					pending_user_seps.clear ();
					transients.add (el);
				} else if (el is FileDockItem) {
					foreach (var sep in pending_user_seps)
						folders.add (sep);
					pending_user_seps.clear ();
					folders.add (el);
				} else if (is_docklet_element (el)) {
					unowned DockItem? item = el as DockItem;
					if (el is PreferencesDockItem || (item != null && item.Prefs != null && item.Prefs.Launcher == "docklet://preferences")) {
						foreach (var sep in pending_user_seps)
							docklets.add (sep);
						pending_user_seps.clear ();
						preferences_docklet = el;
					} else {
						foreach (var sep in pending_user_seps)
							docklets.add (sep);
						pending_user_seps.clear ();
						docklets.add (el);
					}
				} else {
					foreach (var sep in pending_user_seps)
						pinned_apps.add (sep);
					pending_user_seps.clear ();
					pinned_apps.add (el);
				}
			}
			foreach (var sep in pending_user_seps)
				pinned_apps.add (sep);
			pending_user_seps.clear ();

			// Preserve user's relative order within each category if CategorizedDockItems exists
			if (Prefs.CategorizedDockItems != null && Prefs.CategorizedDockItems.length > 0) {
				folders = sort_bucket_by_target (folders, Prefs.CategorizedDockItems);
				docklets = sort_bucket_by_target (docklets, Prefs.CategorizedDockItems);
				pinned_apps = sort_bucket_by_target (pinned_apps, Prefs.CategorizedDockItems);
			}

			// Strictly ordered: [Plank] | [FOLDERS] | [Docklets] | [pinned Apps] | Unpinned apps | [trash]
			var new_order = new Gee.ArrayList<DockElement> ();
			if (preferences_docklet != null) new_order.add (preferences_docklet);
			foreach (var f in folders) new_order.add (f);
			foreach (var d in docklets) new_order.add (d);
			foreach (var p in pinned_apps) new_order.add (p);
			foreach (var t in transients) new_order.add (t);
			if (trash_item != null) new_order.add (trash_item);

			internal_elements.clear ();
			foreach (var el in new_order) {
				internal_elements.add (el);
			}

			// Persist the clean sequence into FreeDockItems
			save_current_order_to (true);

			refresh_separators ();

			unowned DockController? dock = get_dock ();
			if (dock != null && dock.renderer != null && dock.renderer.theme != null) {
				dock.update_items ();
				dock.position_manager.update (dock.renderer.theme);
				dock.renderer.reset_buffers ();
				dock.renderer.animated_draw ();
				dock.schedule_serialize_item_positions ();
				if (dock.window != null) {
					dock.window.set_input_mask ();
				}
			}
		}

		public int get_docklet_count ()
		{
			int count = 0;
			foreach (var element in internal_elements) {
				if (is_docklet_element (element)) {
					count++;
				}
			}
			return count;
		}

		public DockElement? get_anchor_docklet ()
		{
			// 1. If preferences docklet is present, it is ALWAYS the master anchor!
			foreach (var element in internal_elements) {
				if (is_docklet_element (element)) {
					unowned DockItem? item = element as DockItem;
					if (element is PreferencesDockItem || (item != null && item.Prefs != null && item.Prefs.Launcher == "docklet://preferences")) {
						return element;
					}
				}
			}
			// 2. Fallback: if preferences docklet is hidden, the first docklet acts as the anchor!
			foreach (var element in internal_elements) {
				if (is_docklet_element (element)) {
					return element;
				}
			}
			return null;
		}

		bool updating_visible_elements = false;

		protected override void update_visible_elements ()
		{
			foreach (var item in internal_elements) {
				if (item is MinimizedWindowDockItem) {
					item.IsAttached = Prefs.ShowMinimizedPreviews;
					if (item.IsAttached)
						item.RemoveTime = 0;
					continue;
				}
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
				int docklet_count = get_docklet_count ();
				if (docklet_count > 1) {
					DockElement? anchor = get_anchor_docklet ();
					foreach (var element in internal_elements) {
						if (is_docklet_element (element)) {
							element.IsAttached = (element == anchor);
							element.AddTime = 0;
							element.RemoveTime = 0;
						}
					}
				}
			}

			// Clean up consecutive, leading, and trailing separators.
			// Only collapse same-type pairs so a user sep next to an auto group
			// boundary is not wiped (maintain_separator also skips auto when edge is user).
			bool prev_was_sep = true; // Start true so any leading separator is suppressed
			SeparatorDockItem? last_sep = null;
			foreach (var element in internal_elements) {
				if (!element.IsAttached)
					continue;
				if (element is SeparatorDockItem) {
					var sep = (SeparatorDockItem) element;
					if (prev_was_sep) {
						if (last_sep != null && last_sep.is_user_separator () == sep.is_user_separator ()) {
							sep.IsAttached = false;
						} else {
							last_sep = sep;
						}
					} else {
						prev_was_sep = true;
						last_sep = sep;
					}
				} else {
					prev_was_sep = false;
				}
			}
			if (prev_was_sep && last_sep != null) {
				last_sep.IsAttached = false;
			}

			base.update_visible_elements ();

			if (dock != null) {
				dock.refresh_visible_elements ();
			}
		}

		public void refresh_separators ()
		{
			update_visible_elements ();
			unowned DockController? dock = get_dock ();
			if (dock != null) {
				dock.refresh_visible_elements ();
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
		static bool list_ends_with_user_separator (Gee.ArrayList<DockElement> list)
		{
			if (list.size == 0)
				return false;
			var last = list.get (list.size - 1);
			return (last is SeparatorDockItem) && ((SeparatorDockItem) last).is_user_separator ();
		}

		static bool list_starts_with_user_separator (Gee.ArrayList<DockElement> list)
		{
			if (list.size == 0)
				return false;
			var first = list.get (0);
			return (first is SeparatorDockItem) && ((SeparatorDockItem) first).is_user_separator ();
		}

		SeparatorDockItem take_auto_separator (Gee.ArrayList<SeparatorDockItem> pool, ref int pool_idx)
		{
			SeparatorDockItem sep;
			if (pool_idx < pool.size) {
				sep = pool.get (pool_idx);
				pool_idx++;
			} else {
				sep = new SeparatorDockItem ();
				sep.Container = this;
				connect_element (sep);
			}
			sep.AddTime = 0;
			sep.RemoveTime = 0;
			sep.IsAttached = true;
			return sep;
		}

		void append_auto_separator_between (Gee.ArrayList<DockElement> left, Gee.ArrayList<DockElement> right,
			Gee.ArrayList<SeparatorDockItem> pool, ref int pool_idx)
		{
			if (left.size == 0 || right.size == 0)
				return;
			if (list_ends_with_user_separator (left) || list_starts_with_user_separator (right))
				return;
			internal_elements.add (take_auto_separator (pool, ref pool_idx));
		}

		/**
		 * Insert a persistent user separator to the left or right of a pinned item.
		 */
		public void insert_user_separator (DockItem anchor, bool to_the_left)
		{
			if (anchor == null || !internal_elements.contains (anchor))
				return;
			if (anchor is TransientDockItem || anchor is SeparatorDockItem || anchor is TrashDockItem)
				return;
			if (Prefs.LockItems)
				return;

			delay_items_monitor ();
			var dockitem_file = Factory.item_factory.make_separator_dock_item (LaunchersDir);
			if (dockitem_file == null) {
				resume_items_monitor ();
				return;
			}

			var sep = new SeparatorDockItem.with_dockitem_file (dockitem_file);
			DockElement? target = null;
			if (to_the_left) {
				target = anchor;
			} else {
				int idx = internal_elements.index_of (anchor);
				if (idx >= 0 && idx + 1 < internal_elements.size)
					target = internal_elements.get (idx + 1);
			}

			if (target != null)
				add (sep, target);
			else
				add (sep);

			resume_items_monitor ();
			refresh_separators ();
			unowned DockController? dock = get_dock ();
			if (dock != null)
				dock.schedule_serialize_item_positions ();
		}

		/**
		 * Maintains clean grouping and dynamic separators:
		 * - Pinned items (apps, folders, docklets) are grouped on the left.
		 * - Transient (running unpinned) items are grouped in the middle.
		 * - TrashDockItem is permanently anchored at the far right.
		 * - Dynamic auto separators sit between those groups.
		 * - User separators (separator-*.dockitem) stay inside the pinned sequence.
		 */
		void maintain_separator ()
		{
			unowned DockController? dock = get_dock ();
			unowned DockItem? dragging_item = (dock != null && dock.drag_manager.InternalDragActive)
				? dock.drag_manager.DragItem : null;
			if (dragging_item != null)
				return;

			var existing_auto_separators = new Gee.ArrayList<SeparatorDockItem> ();
			TrashDockItem? trash_item = null;

			for (int i = 0; i < internal_elements.size; i++) {
				var el = internal_elements.get (i);
				if (el is SeparatorDockItem) {
					var sep = (SeparatorDockItem) el;
					if (!sep.is_user_separator ())
						existing_auto_separators.add (sep);
				} else if (el is TrashDockItem) {
					trash_item = (TrashDockItem) el;
				}
			}

			if (trash_item != null && dragging_item == null) {
				int trash_idx = internal_elements.index_of (trash_item);
				if (trash_idx >= 0 && trash_idx != internal_elements.size - 1) {
					move_element (internal_elements, trash_idx, internal_elements.size - 1);
				}
			}

			if (Prefs.CategorizeItems) {
				var orphan_transients = new Gee.ArrayList<TransientDockItem> ();
				var folders = new Gee.ArrayList<DockElement> ();
				var pinned_apps = new Gee.ArrayList<DockElement> ();
				var docklets = new Gee.ArrayList<DockElement> ();
				DockElement? preferences_docklet = null;
				var other_docklets = new Gee.ArrayList<DockElement> ();
				var transients = new Gee.ArrayList<DockElement> ();
				var minimized_items = new Gee.ArrayList<DockElement> ();
				var pending_user_seps = new Gee.ArrayList<DockElement> ();

				for (int i = 0; i < internal_elements.size; i++) {
					var el = internal_elements.get (i);
					if (el is TrashDockItem)
						continue;
					if (el is SeparatorDockItem) {
						var sep = (SeparatorDockItem) el;
						if (sep.is_user_separator ())
							pending_user_seps.add (el);
						continue;
					}
					if (el is MinimizedWindowDockItem) {
						foreach (var s in pending_user_seps)
							pinned_apps.add (s);
						pending_user_seps.clear ();
						minimized_items.add (el);
					} else if (el is TransientDockItem) {
						var trans = (TransientDockItem) el;
						var win_count = WindowManager.get_default ().window_count_for_app (trans.Launcher);
						if (win_count <= 0 && !trans.is_running ()) {
							orphan_transients.add (trans);
							continue;
						}
						foreach (var s in pending_user_seps)
							pinned_apps.add (s);
						pending_user_seps.clear ();
						if (!Prefs.PinnedOnly)
							transients.add (el);
					} else if (el is FileDockItem) {
						foreach (var s in pending_user_seps)
							folders.add (s);
						pending_user_seps.clear ();
						folders.add (el);
					} else if (is_docklet_element (el)) {
						unowned DockItem? item = el as DockItem;
						if (el is PreferencesDockItem || (item != null && item.Prefs != null && item.Prefs.Launcher == "docklet://preferences")) {
							foreach (var s in pending_user_seps)
								other_docklets.add (s);
							pending_user_seps.clear ();
							preferences_docklet = el;
						} else {
							foreach (var s in pending_user_seps)
								other_docklets.add (s);
							pending_user_seps.clear ();
							other_docklets.add (el);
						}
					} else {
						foreach (var s in pending_user_seps)
							pinned_apps.add (s);
						pending_user_seps.clear ();
						pinned_apps.add (el);
					}
				}
				foreach (var s in pending_user_seps)
					pinned_apps.add (s);
				pending_user_seps.clear ();

				if (Prefs.SystemMenuAccess == 4 && preferences_docklet == null && dragging_item == null) {
					ensure_preferences_dockitem ();
					preferences_docklet = item_for_uri ("docklet://preferences");
				}

				if (preferences_docklet != null)
					docklets.add (preferences_docklet);
				foreach (var od in other_docklets)
					docklets.add (od);

				foreach (var orphan in orphan_transients) {
					disconnect_element (orphan);
					internal_elements.remove (orphan);
					orphan.Container = null;
					orphan.delete ();
				}

				var groups = new Gee.ArrayList<Gee.ArrayList<DockElement>> ();
				if (folders.size > 0)
					groups.add (folders);
				if (docklets.size > 0)
					groups.add (docklets);
				if (pinned_apps.size > 0)
					groups.add (pinned_apps);
				if (transients.size > 0)
					groups.add (transients);
				if (minimized_items.size > 0)
					groups.add (minimized_items);
				if (trash_item != null) {
					var trash_group = new Gee.ArrayList<DockElement> ();
					trash_group.add (trash_item);
					groups.add (trash_group);
				}

				internal_elements.clear ();
				int sep_pool_idx = 0;
				for (int g = 0; g < groups.size; g++) {
					if (g > 0)
						append_auto_separator_between (groups.get (g - 1), groups.get (g), existing_auto_separators, ref sep_pool_idx);
					foreach (var item in groups.get (g))
						internal_elements.add (item);
				}

				while (sep_pool_idx < existing_auto_separators.size) {
					var unused_sep = existing_auto_separators.get (sep_pool_idx++);
					disconnect_element (unused_sep);
					unused_sep.Container = null;
				}
				return;
			}

			// Classic / Free Mode
			DockElement? preferences_item = null;
			var pinned = new Gee.ArrayList<DockElement> ();
			var transients = new Gee.ArrayList<DockElement> ();
			var minimized_items = new Gee.ArrayList<DockElement> ();
			var orphan_transients = new Gee.ArrayList<TransientDockItem> ();
			var pending_user_seps = new Gee.ArrayList<DockElement> ();

			for (int i = 0; i < internal_elements.size; i++) {
				var el = internal_elements.get (i);
				if (el is TrashDockItem)
					continue;
				if (el is SeparatorDockItem) {
					var sep = (SeparatorDockItem) el;
					if (sep.is_user_separator ())
						pending_user_seps.add (el);
					continue;
				}
				if (el is MinimizedWindowDockItem) {
					foreach (var s in pending_user_seps)
						pinned.add (s);
					pending_user_seps.clear ();
					minimized_items.add (el);
				} else if (el is TransientDockItem) {
					var trans = (TransientDockItem) el;
					var win_count = WindowManager.get_default ().window_count_for_app (trans.Launcher);
					if (win_count <= 0 && !trans.is_running () && dragging_item == null) {
						orphan_transients.add (trans);
						continue;
					}
					foreach (var s in pending_user_seps)
						pinned.add (s);
					pending_user_seps.clear ();
					if (!Prefs.PinnedOnly)
						transients.add (el);
				} else {
					unowned DockItem? item = el as DockItem;
					if (el is PreferencesDockItem || (item != null && item.Prefs != null && item.Prefs.Launcher == "docklet://preferences")) {
						if (preferences_item == null) {
							foreach (var s in pending_user_seps)
								pinned.add (s);
							pending_user_seps.clear ();
							preferences_item = el;
						} else {
							foreach (var s in pending_user_seps)
								pinned.add (s);
							pending_user_seps.clear ();
							pinned.add (el);
						}
					} else {
						foreach (var s in pending_user_seps)
							pinned.add (s);
						pending_user_seps.clear ();
						pinned.add (el);
					}
				}
			}
			foreach (var s in pending_user_seps)
				pinned.add (s);
			pending_user_seps.clear ();

			if (Prefs.SystemMenuAccess == 4 && preferences_item == null && dragging_item == null) {
				ensure_preferences_dockitem ();
				preferences_item = item_for_uri ("docklet://preferences");
			}

			foreach (var orphan in orphan_transients) {
				disconnect_element (orphan);
				internal_elements.remove (orphan);
				orphan.Container = null;
				orphan.delete ();
			}

			internal_elements.clear ();
			int sep_pool_idx = 0;

			var prefs_group = new Gee.ArrayList<DockElement> ();
			if (preferences_item != null)
				prefs_group.add (preferences_item);

			if (preferences_item != null)
				internal_elements.add (preferences_item);

			if (preferences_item != null && pinned.size > 0)
				append_auto_separator_between (prefs_group, pinned, existing_auto_separators, ref sep_pool_idx);

			foreach (var p in pinned)
				internal_elements.add (p);

			if (pinned.size > 0 && transients.size > 0)
				append_auto_separator_between (pinned, transients, existing_auto_separators, ref sep_pool_idx);
			else if (preferences_item != null && pinned.size == 0 && transients.size > 0)
				append_auto_separator_between (prefs_group, transients, existing_auto_separators, ref sep_pool_idx);

			foreach (var t in transients)
				internal_elements.add (t);

			var before_min = new Gee.ArrayList<DockElement> ();
			if (pinned.size > 0)
				before_min.add_all (pinned);
			else if (transients.size > 0)
				before_min.add_all (transients);
			else if (preferences_item != null)
				before_min.add (preferences_item);

			if (minimized_items.size > 0 && before_min.size > 0) {
				var edge = (transients.size > 0) ? transients : (pinned.size > 0 ? pinned : prefs_group);
				append_auto_separator_between (edge, minimized_items, existing_auto_separators, ref sep_pool_idx);
			}

			foreach (var m in minimized_items)
				internal_elements.add (m);

			if (trash_item != null) {
				var trash_group = new Gee.ArrayList<DockElement> ();
				trash_group.add (trash_item);
				var edge = minimized_items.size > 0 ? minimized_items
					: (transients.size > 0 ? transients
					: (pinned.size > 0 ? pinned : prefs_group));
				if (edge.size > 0)
					append_auto_separator_between (edge, trash_group, existing_auto_separators, ref sep_pool_idx);
				internal_elements.add (trash_item);
			}

			while (sep_pool_idx < existing_auto_separators.size) {
				var unused_sep = existing_auto_separators.get (sep_pool_idx++);
				disconnect_element (unused_sep);
				unused_sep.Container = null;
			}
		}

		public override void prepare ()
		{
			base.prepare ();

			var favs = new Gee.ArrayList<string> ();

			foreach (var element in internal_elements) {
				unowned ApplicationDockItem? item = (element as ApplicationDockItem);
				if (item != null)
					favs.add (item.Launcher);
			}

			Matcher.get_default ().set_favorites (favs);
		}

		protected override bool is_pinned_only ()
		{
			return Prefs.PinnedOnly;
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

		public override void sync_compositor_windows ()
		{
			base.sync_compositor_windows ();

			var windows = WindowControl.get_windows ();
			var discovery = ApplicationDiscovery.get_default ();
			var my_pid = Posix.getpid ();

			/* Show ALL minimized windows as dock items. Memory is controlled by
			 * lazy/on-demand ScreenShot2 (hover + small LRU live-thumb cache in
			 * KWinThumbnailService), NOT by hiding icons. WindowCards remains
			 * the full-size preview UI. */
			var active_minimized_uuids = new Gee.HashSet<string> ();

			if (Prefs.ShowMinimizedPreviews) {
				DockElement? trash_target = null;
				foreach (var element in internal_elements) {
					if (element is TrashDockItem) {
						trash_target = element;
						break;
					}
				}

				var minimized_windows = new Gee.ArrayList<WindowInfo> ();
				foreach (var window in windows) {
					if (window.Pid > 0 && window.Pid == my_pid)
						continue;

					var app_id = window.ApplicationId.down ();
					var res_class = window.ResourceClass.down ();
					var res_name = window.ResourceName.down ();
					var desk_name = window.DesktopFileName.down ();
					var caption = window.Caption.down ();
					if (app_id == "kde-dockbar" || app_id == "wayplank" || app_id == "plank" ||
					    res_class == "kde-dockbar" || res_class == "wayplank" || res_class == "plank" ||
					    res_name == "kde-dockbar" || res_name == "wayplank" || res_name == "plank" ||
					    desk_name == "kde-dockbar.desktop" || desk_name == "wayplank.desktop" || desk_name == "plank.desktop" || desk_name == "kde-dockbar" || desk_name == "wayplank" || desk_name == "plank" ||
					    caption == "kde-dockbar" || caption == "wayplank" || caption == "wayplank-hover")
						continue;

					if (window.Minimized)
						minimized_windows.add (window);
				}

				// Newest minimize first (higher MinimizedSequence)
				minimized_windows.sort ((a, b) => {
					if (a.MinimizedSequence < b.MinimizedSequence)
						return 1;
					if (a.MinimizedSequence > b.MinimizedSequence)
						return -1;
					return a.Id.collate (b.Id);
				});

				foreach (var window in minimized_windows) {
					active_minimized_uuids.add (window.Id);

					MinimizedWindowDockItem? existing_min = null;
					foreach (var element in internal_elements) {
						if (element is MinimizedWindowDockItem && ((MinimizedWindowDockItem) element).WindowId == window.Id) {
							existing_min = (MinimizedWindowDockItem) element;
							break;
						}
					}

					if (existing_min != null) {
						existing_min.update_caption (window.Caption);
					} else {
						var desktop_file = discovery.best_desktop_file_for_window (window);
						string icon_name = "";
						string launcher_uri = "";
						if (desktop_file != null) {
							launcher_uri = desktop_file.get_uri ();
							try {
								var kf = new KeyFile ();
								kf.load_from_file (desktop_file.get_path (), KeyFileFlags.NONE);
								if (kf.has_key (KeyFileDesktop.GROUP, KeyFileDesktop.KEY_ICON))
									icon_name = kf.get_string (KeyFileDesktop.GROUP, KeyFileDesktop.KEY_ICON);
							} catch (Error e) { }
						}
						if (icon_name == "") {
							icon_name = window.ResourceClass.length > 0 ? window.ResourceClass.down () : "application-default-icon";
						}

						var min_item = new MinimizedWindowDockItem (window.Id, window.Caption, icon_name, launcher_uri);
						add (min_item, trash_target);
					}
				}
			}

			foreach (var element in internal_elements.to_array ()) {
				if (element is MinimizedWindowDockItem) {
					var min_item = (MinimizedWindowDockItem) element;
					if (!active_minimized_uuids.contains (min_item.WindowId)) {
						KWinThumbnailService.get_default ().remove_cached (min_item.WindowId);
						min_item.reset_buffers ();
						remove (min_item);
					}
				}
			}

			unowned DockController? dock = get_dock ();
			if (dock != null) {
				dock.sync_minimized_geometries ();
			}
		}

		void handle_setting_changed ()
		{
			update_visible_elements ();
		}

		void handle_pinned_only_changed ()
		{
			sync_compositor_windows ();
			update_visible_elements ();

			unowned DockController? dock = get_dock ();
			if (dock != null && dock.renderer != null && dock.renderer.theme != null) {
				dock.refresh_visible_elements ();
				dock.position_manager.update (dock.renderer.theme);
				dock.renderer.reset_buffers ();
				dock.schedule_serialize_item_positions ();
				if (dock.window != null) {
					dock.window.set_input_mask ();
				}
				dock.renderer.animated_draw ();
			}
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
				bool still_running = (win_count > 0);
				if (internal_elements.contains (item))
					remove (item);
				item.delete ();
				
				// Re-add as a temporary item only if the app has active open windows or running process
				if (still_running) {
					DockElement? trash_target = null;
					foreach (var el in internal_elements) {
						if (el is TrashDockItem) {
							trash_target = el;
							break;
						}
					}
					var new_item = new TransientDockItem.with_launcher (launcher_uri);
					add (new_item, trash_target);
				}
			}

			resume_items_monitor ();
			refresh_separators ();
			unowned DockController? dock = get_dock ();
			if (dock != null)
				dock.schedule_serialize_item_positions ();
		}
	}
}
