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
	 * Handles all of the drawing for a dock.
	 */
	public class DockRenderer : Renderer
	{
		public DockController controller { private get; construct; }
		
		public DockTheme theme { get; private set; }
		
		/**
		 * The current progress [0.0..1.0] of the hide-animation of the dock.
		 */
		[CCode (notify = false)]
		public double hide_progress { get; private set; }
		
		/**
		 * The current opacity of the dock.
		 */
		[CCode (notify = false)]
		double opacity { get; private set; }
		
		/**
		 * The current progress [0.0..1.0] of the zoom-in-animation of the dock.
		 */
		[CCode (notify = false)]
		public double zoom_in_progress { get; private set; }
		
		/**
		 * The current local cursor-position on the dock if hovered.
		 */
		public Gdk.Point local_cursor;

		Surface? main_buffer = null;
		Surface? fade_buffer = null;
		Surface? item_buffer = null;
		Surface? shadow_buffer = null;
		
		Surface? background_buffer = null;
		Gdk.Rectangle background_rect;
		Surface? indicator_buffer = null;
		Surface? urgent_indicator_buffer = null;
		Surface? urgent_glow_buffer = null;
		
		int64 last_hide = 0LL;
		int64 last_hovered_changed = 0LL;
		
		bool screen_is_composited = false;
		bool show_notifications = true;
		uint reset_position_manager_timer_id = 0U;
		int window_scale_factor = 1;
		bool is_first_frame = true;
		bool zoom_changed = false;
		
		ulong gtk_theme_name_changed_handler_id = 0UL;
		
		double dynamic_animation_offset = 0.0;
		public int64 current_frame_time { get; private set; default = 0LL; }
		
		Gee.ArrayList<unowned DockItem> current_items;
		Gee.HashSet<DockItem> transient_items;
#if BENCHMARK
		Gee.ArrayList<string> benchmark;
#endif
		
		/**
		 * Create a new dock renderer for a dock.
		 *
		 * @param controller the dock controller to manage drawing for
		 * @param window the dock window to be animated
		 */
		public DockRenderer (DockController controller, Gtk.Window window)
		{
			GLib.Object (controller : controller, widget : window);
		}
		
		construct
		{
			transient_items = new Gee.HashSet<DockItem> ();
			current_items = new Gee.ArrayList<unowned DockItem> ();
#if BENCHMARK
			benchmark = new Gee.ArrayList<string> ();
#endif
			controller.prefs.notify.connect (prefs_changed);
			SystemTheme.get_default ().theme_changed.connect (on_system_theme_changed);
			
			load_theme ();
		}
		
		/**
		 * Initializes the renderer.  Call after the DockWindow is constructed.
		 */
		public void initialize ()
			requires (controller.window != null)
		{
			controller.position_manager.update (theme);
			
			controller.window.notify["HoveredItem"].connect (animated_draw);
			controller.hide_manager.notify["Hidden"].connect (hidden_changed);
			controller.hide_manager.notify["Hovered"].connect (hovered_changed);
		}
		
		~DockRenderer ()
		{
			SystemTheme.get_default ().theme_changed.disconnect (on_system_theme_changed);

			if (controller != null) {
				controller.prefs.notify.disconnect (prefs_changed);
				if (controller.hide_manager != null) {
					controller.hide_manager.notify["Hidden"].disconnect (hidden_changed);
					controller.hide_manager.notify["Hovered"].disconnect (hovered_changed);
				}
				if (controller.window != null) {
					controller.window.notify["HoveredItem"].disconnect (animated_draw);
				}
			}
			if (theme != null) {
				theme.notify.disconnect (theme_changed);
			}
		}

		void on_system_theme_changed (bool is_dark)
		{
			if (controller.prefs.Theme == Theme.AUTO_NAME) {
				load_theme ();
			}
		}
		
		void prefs_changed (Object prefs, ParamSpec prop)
		{
			switch (prop.name) {
			case "Alignment":
			case "IconSize":
			case "ItemsAlignment":
			case "Offset":
			case "Position":
				reset_position_manager ();
				break;
			case "Theme":
				load_theme ();
				break;
			default:
				// Nothing important for us changed
				break;
			}
		}
		
		void theme_changed ()
		{
			reset_position_manager ();
		}
		
		void reset_position_manager ()
		{
			// Don't perform an update immediately and summon further
			// update-requests, wait at least 50ms after the last request
			
			if (reset_position_manager_timer_id > 0U)
				Source.remove (reset_position_manager_timer_id);
			
			reset_position_manager_timer_id = Gdk.threads_add_timeout (50, () => {
				reset_position_manager_timer_id = 0U;
				
				reset_buffers ();
				reset_item_buffers ();
				controller.position_manager.update (theme);
				
				return false;
			});
		}
		
		void load_theme ()
		{
			var is_reload = (theme != null);
			
			if (is_reload)
				theme.notify.disconnect (theme_changed);
			
			unowned string name = controller.prefs.Theme;
			if (name == Theme.GTK_THEME_NAME) {
				if (gtk_theme_name_changed_handler_id == 0UL)
					gtk_theme_name_changed_handler_id = Gtk.Settings.get_default ().notify["gtk-theme-name"].connect (load_theme);
			} else if (gtk_theme_name_changed_handler_id > 0UL) {
				SignalHandler.disconnect (Gtk.Settings.get_default (), gtk_theme_name_changed_handler_id);
				gtk_theme_name_changed_handler_id = 0UL;
			}
			
			theme = new DockTheme (name);
			theme.load ("dock");
			theme.notify.connect (theme_changed);
			
			unowned Gtk.Settings? gtk_settings = Gtk.Settings.get_default ();
			if (gtk_settings != null) {
				gtk_settings.gtk_application_prefer_dark_theme = !theme.is_light ();
			}
			
			if (is_reload)
				theme_changed ();
		}
		
		/**
		 * Resets all internal buffers and forces a redraw.
		 */
		public void reset_buffers ()
		{
			Logger.verbose ("DockRenderer.reset_buffers ()");
			
			main_buffer = null;
			fade_buffer = null;
			item_buffer = null;
			shadow_buffer = null;
			
			background_buffer = null;
			indicator_buffer = null;
			urgent_indicator_buffer = null;
			urgent_glow_buffer = null;
			
			animated_draw ();
		}
		
		/**
		 * Resets all internal item buffers and forces a redraw.
		 */
		void reset_item_buffers ()
		{
			Logger.verbose ("DockRenderer.reset_item_buffers ()");
			
			controller.reset_buffers ();
			
			animated_draw ();
		}
		
		/**
		 * {@inheritDoc}
		 */
		protected override void initialize_frame (int64 frame_time)
		{
			current_frame_time = frame_time;
			return_if_fail (theme != null);
			
			unowned Gee.ArrayList<unowned DockItem> new_items = controller.VisibleItems;
			
			// FIXME This should never happen
			if (new_items.size <= 0) {
				critical ("No items available to initialize frame");
				return;
			}
			
			unowned PositionManager position_manager = controller.position_manager;
			
			screen_is_composited = position_manager.screen_is_composited;
			show_notifications = EnvironmentSettings.get_instance ().ShowNotifications;
			dynamic_animation_offset = 0.0;
			
			var fade_opacity = theme.FadeOpacity;
			
			if (screen_is_composited) {
				var hide_duration = (fade_opacity == 1.0 ? theme.HideTime : theme.FadeTime) * 1000;
				var hide_time = int64.max (0LL, frame_time - last_hide);
				if (hide_time < hide_duration) {
					if (controller.hide_manager.Hidden)
						hide_progress = easing_for_mode (AnimationMode.EASE_IN_CUBIC, hide_time, hide_duration);
					else
						hide_progress = 1.0 - easing_for_mode (AnimationMode.EASE_OUT_CUBIC, hide_time, hide_duration);
				} else {
					hide_progress = (controller.hide_manager.Hidden ? 1.0 : 0.0);
				}
				
				var zoom_duration = DOCK_ZOOM_DURATION * 1000;
				var zoom_time = int64.max (0LL, frame_time - last_hovered_changed);
				double zoom_progress;
				if (zoom_time < zoom_duration) {
					if (controller.hide_manager.Hovered)
						zoom_progress = easing_for_mode (AnimationMode.EASE_OUT_CUBIC, zoom_time, zoom_duration);
					else
						zoom_progress = 1.0 - easing_for_mode (AnimationMode.EASE_IN_CUBIC, zoom_time, zoom_duration);
				} else {
					zoom_progress = (controller.hide_manager.Hovered ? 1.0 : 0.0);
				}
				zoom_in_progress = zoom_progress * (1.0 - hide_progress);
			} else {
				hide_progress = 0.0;
				zoom_in_progress = 0.0;
			}
			
			if (fade_opacity < 1.0)
				opacity = 1.0 - (1.0 - fade_opacity) * hide_progress;
			else
				opacity = 1.0;
			
			// Update *ordered* list of items
			current_items.clear ();
			current_items.add_all (new_items);
			
			if (screen_is_composited) {
				var add_time = 0LL;
				var remove_time = 0LL;
				var move_time = 0LL;
				var move_duration = theme.ItemMoveTime * 1000;
				
				var transient_items_it = transient_items.iterator ();
				while (transient_items_it.next ()) {
					var item = transient_items_it.get ();
					add_time = item.AddTime;
					remove_time = item.RemoveTime;
					
					if (add_time > remove_time) {
						move_time = frame_time - add_time;
						if (move_time < move_duration) {
							if (!current_items.contains (item))
								current_items.add (item);
						} else {
							transient_items_it.remove ();
						}
					} else if (remove_time > 0) {
						move_time = frame_time - remove_time;
						if (move_time < move_duration) {
							if (!current_items.contains (item))
								current_items.add (item);
						} else {
							transient_items_it.remove ();
						}
					}
				}
			} else {
				transient_items.clear ();
			}
			
			current_items.sort ((CompareDataFunc) compare_dock_item_position);
			
			// Calculate positions for given ordered list of items
			position_manager.update_draw_values (current_items,
				(DrawValueFunc) animate_draw_value_for_item,
				(DrawValuesFunc) post_process_draw_values);
			
			background_rect = position_manager.get_background_region ();
		}
		
		/**
		 * {@inheritDoc}
		 */
		public override void draw (Cairo.Context cr, int64 frame_time)
		{
			current_frame_time = frame_time;

			// FIXME This should never happen
			if (current_items.size <= 0) {
				critical ("No items available to draw frame");
				return;
			}
			
			window_scale_factor = controller.window.get_window ().get_scale_factor ();
			// take the previous frame values into account to decide if we
			// can bail a full draw to not miss a finishing animation-frame
			var no_full_draw_needed = (!is_first_frame && hide_progress == 1.0 && opacity == 1.0);
			
			unowned PositionManager position_manager = controller.position_manager;
			unowned DockItem dragged_item = controller.drag_manager.DragItem;
			var win_rect = position_manager.get_dock_window_region ();
			
			if (main_buffer == null) {
				main_buffer = new Surface.with_cairo_surface (win_rect.width, win_rect.height, cr.get_target ());
				main_buffer.Internal.set_device_scale (window_scale_factor, window_scale_factor);
			}
			
			if (item_buffer == null) {
				item_buffer = new Surface.with_cairo_surface (win_rect.width, win_rect.height, cr.get_target ());
				item_buffer.Internal.set_device_scale (window_scale_factor, window_scale_factor);
			}
			
			if (shadow_buffer == null) {
				shadow_buffer = new Surface.with_cairo_surface (win_rect.width, win_rect.height, cr.get_target ());
				shadow_buffer.Internal.set_device_scale (window_scale_factor, window_scale_factor);
			}
			
			// if the dock is completely hidden and not transparently drawn
			// only draw ugent-glow indicators and bail since there is no need
			// for further things
			if (no_full_draw_needed && hide_progress == 1.0 && opacity == 1.0) {
				// we still need to clear out the previous output
				cr.save ();
				cr.set_operator (Cairo.Operator.CLEAR);
				cr.paint ();
				cr.restore ();
				
				if (show_notifications)
					foreach (unowned DockItem item in current_items)
						draw_urgent_glow (item, cr, frame_time);
				
				return;
			}

			if (opacity < 1.0 && fade_buffer == null) {
				fade_buffer = new Surface.with_cairo_surface (win_rect.width, win_rect.height, cr.get_target ());
				fade_buffer.Internal.set_device_scale (window_scale_factor, window_scale_factor);
			}
			
#if BENCHMARK
			DateTime start, start2, end, end2;
			benchmark.clear ();
			start = new DateTime.now_local ();
#endif
			
			main_buffer.clear ();
			item_buffer.clear ();
			shadow_buffer.clear ();
			unowned Cairo.Context item_cr = item_buffer.Context;
			unowned Cairo.Context shadow_cr = shadow_buffer.Context;
			
			// calculate drawing offset
			var x_offset = 0, y_offset = 0;
			if (opacity == 1.0)
				position_manager.get_dock_draw_position (out x_offset, out y_offset);
			
			// composite dock layers and make sure to draw onto the window's context with one operation
			main_buffer.clear ();
			unowned Cairo.Context main_cr = main_buffer.Context;
			main_cr.set_operator (Cairo.Operator.OVER);
			
#if BENCHMARK
			start2 = new DateTime.now_local ();
#endif
			// draw background-layer
			draw_dock_background (main_cr, background_rect, x_offset, y_offset);
#if BENCHMARK
			end2 = new DateTime.now_local ();
			benchmark.add ("background render time - %f ms".printf (end2.difference (start2) / 1000.0));
#endif
			
			// Clip items and shadows to the dock background area so scrolled-out items don't leak
			bool need_scroll_clip = (position_manager.max_scroll_offset > 0.0);
			if (need_scroll_clip) {
				item_cr.save ();
				shadow_cr.save ();
				if (position_manager.is_horizontal_dock ()) {
					// Horizontal dock: clip along X scroll axis, keep full height for zoom/bounce
					item_cr.rectangle (background_rect.x, 0, background_rect.width, win_rect.height);
					shadow_cr.rectangle (background_rect.x, 0, background_rect.width, win_rect.height);
				} else {
					// Vertical dock: clip along Y scroll axis, keep full width for zoom/bounce
					item_cr.rectangle (0, background_rect.y, win_rect.width, background_rect.height);
					shadow_cr.rectangle (0, background_rect.y, win_rect.width, background_rect.height);
				}
				item_cr.clip ();
				shadow_cr.clip ();
			}

			// draw each item onto the dock buffer
			foreach (unowned DockItem item in current_items) {
#if BENCHMARK
				start2 = new DateTime.now_local ();
#endif
				// Do not draw the currently dragged item
				if (item.IsVisible && dragged_item != item) {
					var draw_value = position_manager.get_draw_value_for_item (item);
					draw_item (item_cr, item, draw_value, frame_time);
					draw_item_shadow (shadow_cr, item, draw_value);
				}
#if BENCHMARK
				end2 = new DateTime.now_local ();
				benchmark.add ("item render time - %f ms".printf (end2.difference (start2) / 1000.0));
#endif
			}

			if (need_scroll_clip) {
				item_cr.restore ();
				shadow_cr.restore ();
			}
			
			update_separator_colors ();
			
			// draw items-shadow-layer
			main_cr.set_source_surface (shadow_buffer.Internal, x_offset, y_offset);
			main_cr.paint ();
			
			// draw items-layer
			main_cr.set_source_surface (item_buffer.Internal, x_offset, y_offset);
			main_cr.paint ();

			// draw scroll indicators if overflowed
			if (position_manager.max_scroll_offset > 0.0 && position_manager.is_horizontal_dock ()) {
				draw_scroll_edge_indicators (main_cr, background_rect);
			}
			
			// draw the dock on the window and fade it if need be
			cr.set_operator (Cairo.Operator.SOURCE);
			if (opacity < 1.0) {
				fade_buffer.clear ();
				unowned Cairo.Context fade_cr = fade_buffer.Context;
				fade_cr.set_operator (Cairo.Operator.OVER);
				fade_cr.set_source_surface (main_buffer.Internal, 0, 0);
				fade_cr.paint_with_alpha (opacity);
				
				cr.set_source_surface (fade_buffer.Internal, 0, 0);
			} else {
				cr.set_source_surface (main_buffer.Internal, 0, 0);
			}
			cr.paint ();
			
			// draw urgent-glow if dock is completely hidden
			if (show_notifications && hide_progress == 1.0) {
				foreach (unowned DockItem item in current_items)
					draw_urgent_glow (item, cr, frame_time);
			}
			
#if BENCHMARK
			end = new DateTime.now_local ();
			var diff = end.difference (start) / 1000.0;
			if (diff > 5.0)
				foreach (var s in benchmark)
					message ("	" + s);
			message ("render time - %f ms", diff);
#endif
			
			if (is_first_frame) {
				message ("Cairo.SurfaceType: %s", cairo_surface_type_to_string (cr.get_target ().get_type ()));
				
				Gdk.threads_add_idle_full (GLib.Priority.LOW, () => {
					unowned HideManager hide_manager = controller.hide_manager;
					
					// FIXME HideManager.initialize () -> setup_active_window ();
					// is already taking care of updating the Hidden-state,
					// but only if there is already an active/open window
					if (hide_manager.Hidden)
						return false;
					
					// slide the dock in, if it shouldnt start hidden
					hide_manager.update_hovered ();
					
					// FIXME there must be a sane way
					// https://github.com/sergiomelas/wayplank/issues/+bug/1256626
					force_frame_time_update ();
					last_hide = frame_time;
					
					hidden_changed ();
					return false;
				});
				
				is_first_frame = false;
			}
		}
		
		/**
		 * Updates the color of any real SeparatorDockItem present, based on how
		 * the dock background actually renders (only touches the item's cache
		 * when the color actually changed, to avoid needless redraw churn).
		 */
		Color? last_separator_color = null;
		
		void update_separator_colors ()
		{
			var reference = theme.FillEndColor;
			var luminance = 0.299 * reference.red + 0.587 * reference.green + 0.114 * reference.blue;
			var is_light = (reference.alpha < 0.35 || luminance > 0.5);
			var alpha = (is_light ? 0.42 : 0.58);
			
			var color = (is_light
				? Color () { red = 0.0, green = 0.0, blue = 0.0, alpha = alpha }
				: Color () { red = 1.0, green = 1.0, blue = 1.0, alpha = alpha });
			
			if (last_separator_color != null
				&& last_separator_color.red == color.red
				&& last_separator_color.green == color.green
				&& last_separator_color.blue == color.blue
				&& last_separator_color.alpha == color.alpha)
				return;
			
			last_separator_color = color;
			
			foreach (unowned DockItem item in current_items) {
				unowned SeparatorDockItem? sep = (item as SeparatorDockItem);
				if (sep != null)
					sep.BarColor = color;
			}
		}
		
		void draw_dock_background (Cairo.Context cr, Gdk.Rectangle background_rect, int x_offset, int y_offset)
		{
			unowned PositionManager position_manager = controller.position_manager;
			
			if (background_rect.width <= 0 || background_rect.height <= 0) {
				background_buffer = null;
				return;
			}
			
			if (hide_progress > 0.0 && theme.CascadeHide) {
				int x, y;
				position_manager.get_background_padding (out x, out y);
				x_offset -= (int) (x * hide_progress);
				y_offset -= (int) (y * hide_progress);
			}

			if (ApplicationDockItem.is_animating_cards ()) {
				// Zero-allocation direct vector drawing during card animation
				theme.draw_dock_background_direct (cr, background_rect.x + x_offset, background_rect.y + y_offset,
					background_rect.width, background_rect.height, position_manager.Position);
				return;
			}
			
			if (background_buffer == null || background_buffer.Width != background_rect.width
				|| background_buffer.Height != background_rect.height)
				background_buffer = theme.create_background (background_rect.width, background_rect.height,
					position_manager.Position, main_buffer);
			
			cr.set_source_surface (background_buffer.Internal, background_rect.x + x_offset, background_rect.y + y_offset);
			cr.paint ();
		}
		
		[CCode (instance_pos = -1)]
		void animate_draw_value_for_item (DockItem item, DockItemDrawValue draw_value)
		{
			unowned PositionManager position_manager = controller.position_manager;
			unowned DockItem hovered_item = controller.window.HoveredItem;
			unowned DragManager drag_manager = controller.drag_manager;
			
			var icon_size = (int) draw_value.icon_size;
			var position = position_manager.Position;
			var x_offset = 0.0, y_offset = 0.0;
			
			// check for and calculate click-animation
			var max_click_time = item.ClickedAnimation == AnimationType.BOUNCE ? theme.LaunchBounceTime : theme.ClickTime;
			max_click_time *= 1000;
			var click_time = int64.max (0LL, frame_time - item.LastClicked);
			if (click_time < max_click_time) {
				var click_animation_progress = click_time / (double) max_click_time;
				
				switch (item.ClickedAnimation) {
				default:
				case AnimationType.NONE:
					break;
				case AnimationType.BOUNCE:
					if (screen_is_composited)
						y_offset += position_manager.LaunchBounceHeight * easing_bounce (click_time, max_click_time, 2);
					break;
				case AnimationType.DARKEN:
					draw_value.darken = double.max (0, Math.sin (Math.PI * click_animation_progress)) * 0.5;
					break;
				case AnimationType.LIGHTEN:
					draw_value.lighten = double.max (0, Math.sin (Math.PI * click_animation_progress)) * 0.5;
					break;
				}
			}
			
			// check for and calculate scroll-animation
			var max_scroll_time = ITEM_SCROLL_DURATION * 1000;
			var scroll_time = int64.max (0LL, frame_time - item.LastScrolled);
			if (scroll_time < max_scroll_time) {
				var scroll_animation_progress = scroll_time / (double) max_scroll_time;
				
				switch (item.ScrolledAnimation) {
				default:
				case AnimationType.NONE:
					break;
				case AnimationType.DARKEN:
					draw_value.darken = double.max (0, Math.sin (Math.PI * scroll_animation_progress)) * 0.5;
					break;
				case AnimationType.LIGHTEN:
					draw_value.lighten = double.max (0, Math.sin (Math.PI * scroll_animation_progress)) * 0.5;
					break;
				}
			}
			
			// check for and calculate hover-animation
			var max_hover_time = ITEM_HOVER_DURATION * 1000;
			var hover_time = int64.max (0LL, frame_time - item.LastHovered);
			if (hover_time < max_hover_time) {
				var hover_animation_progress = 0.0;
				if (hovered_item == item) {
					hover_animation_progress = easing_for_mode (AnimationMode.LINEAR, hover_time, max_hover_time);
				} else {
					hover_animation_progress = 1.0 - easing_for_mode (AnimationMode.LINEAR, hover_time, max_hover_time);
				}
				
				switch (item.HoveredAnimation) {
				default:
				case AnimationType.NONE:
					break;
				case AnimationType.LIGHTEN:
					draw_value.lighten = hover_animation_progress * 0.2;
					break;
				}
			} else if (hovered_item == item) {
				draw_value.lighten = 0.2;
			}
			
			if (hovered_item == item && controller.window.menu_is_visible ())
				draw_value.darken += 0.4;
			else if (drag_manager.ExternalDragActive
				&& (drag_manager.DragNeedsCheck || item is FileDockItem)
				&& !drag_manager.drop_is_accepted_by (item))
				draw_value.darken += 0.6;
			
			// bounce icon on urgent state
			if (screen_is_composited && show_notifications && (item.State & ItemState.URGENT) != 0) {
				var urgent_duration = theme.UrgentBounceTime * 1000;
				var urgent_time = int64.max (0LL, frame_time - item.LastUrgent);
				var urgent_cycle = urgent_time % (2000 * 1000);
				if (urgent_cycle < urgent_duration)
					y_offset += position_manager.UrgentBounceHeight * easing_bounce (urgent_cycle, urgent_duration, 1.0);
			}
			
			// animate addition/removal
			unowned DockContainer? container = item.Container;
			if (item is WindowCardDockItem) {
				var card = (WindowCardDockItem) item;
				double progress = card.get_animation_progress (frame_time, theme.ItemMoveTime);
				draw_value.opacity = progress;
				draw_value.show_indicator = false;
			}

			var allow_animation = (screen_is_composited && !(item is SeparatorDockItem) && !(item is WindowCardDockItem) && (container == null || container.AddTime < item.AddTime));
			if (allow_animation && item.AddTime > item.RemoveTime) {
				var move_duration = theme.ItemMoveTime * 1000;
				var move_time = int64.max (0LL, frame_time - item.AddTime);
				if (move_time < move_duration) {
					var move_animation_progress = 1.0 - easing_for_mode (AnimationMode.LINEAR, move_time, move_duration);
					draw_value.opacity = easing_for_mode (AnimationMode.EASE_IN_EXPO, move_time, move_duration);
					y_offset -= move_animation_progress * (icon_size + position_manager.BottomPadding);
					draw_value.show_indicator = false;
					
					// calculate the resulting incremental dynamic-animation-offset used to animate the background-resize and icon-offset
					move_animation_progress = 1.0 - easing_for_mode (AnimationMode.EASE_OUT_QUINT, move_time, move_duration);
					dynamic_animation_offset -= move_animation_progress * (icon_size + position_manager.ItemPadding);
					x_offset += dynamic_animation_offset;
				}
			} else if (allow_animation && item.RemoveTime > 0) {
				var move_duration = theme.ItemMoveTime * 1000;
				var move_time = int64.max (0LL, frame_time - item.RemoveTime);
				if (move_time < move_duration) {
					var move_animation_progress = easing_for_mode (AnimationMode.LINEAR, move_time, move_duration);
					draw_value.opacity = 1.0 - easing_for_mode (AnimationMode.EASE_OUT_EXPO, move_time, move_duration);
					y_offset -= move_animation_progress * (icon_size + position_manager.BottomPadding);
					draw_value.show_indicator = false;
					
					// calculate the resulting incremental dynamic-animation-offset used to animate the background-resize and icon-offset
					move_animation_progress = 1.0 - easing_for_mode (AnimationMode.EASE_IN_QUINT, move_time, move_duration);
					dynamic_animation_offset += move_animation_progress * (icon_size + position_manager.ItemPadding);
					x_offset += dynamic_animation_offset - (icon_size + position_manager.ItemPadding);
				}
			}
			
			// animate icon movement on move state
			if ((item.State & ItemState.MOVE) != 0) {
				if (ApplicationDockItem.is_animating_cards ()) {
					item.unset_move_state ();
				} else {
					var move_duration = theme.ItemMoveTime * 1000;
					var move_time = int64.max (0LL, frame_time - item.LastMove);
					if (move_time < move_duration) {
						var move_animation_progress = 0.0;
						if (transient_items.size > 0) {
							if (dynamic_animation_offset > 0)
								move_animation_progress = 1.0 - easing_for_mode (AnimationMode.EASE_IN_QUINT, move_time, move_duration);
							else
								move_animation_progress = 1.0 - easing_for_mode (AnimationMode.EASE_OUT_QUINT, move_time, move_duration);
						} else {
							move_animation_progress = 1.0 - easing_for_mode (AnimationMode.EASE_OUT_CIRC, move_time, move_duration);
						}
						var change = move_animation_progress * (icon_size + position_manager.ItemPadding);
						x_offset += (item.Position < item.LastPosition ? change : -change);
					} else {
						item.unset_move_state ();
					}
				}
			}
			
			// animate icon on invalid state
			if ((item.State & ItemState.INVALID) != 0) {
				var invalid_duration = ITEM_INVALID_DURATION * 1000;
				var invalid_time = int64.max (0LL, frame_time - item.LastValid);
				if (invalid_time < invalid_duration) {
					draw_value.opacity = 0.10 + (0.90 * (Math.cos (invalid_time / (double) invalid_duration * 4.5 * Math.PI) + 1) / 2);
				} else {
					draw_value.opacity = 0.10;
				}
			}
			
			if (x_offset != 0.0)
				draw_value.move_right (position, x_offset);
			
			if (y_offset != 0.0)
				draw_value.move_in (position, y_offset);
		}
		
		[CCode (instance_pos = -1)]
		void post_process_draw_values (Gee.HashMap<DockElement, DockItemDrawValue?> draw_values)
		{
			if (dynamic_animation_offset == 0.0)
				return;
			
			unowned PositionManager position_manager = controller.position_manager;
			var position = position_manager.Position;
			
			var x_offset = 0.0;
			
			switch (position_manager.Alignment) {
			default:
			case Gtk.Align.CENTER:
				x_offset -= Math.round (dynamic_animation_offset / 2.0);
				break;
			case Gtk.Align.START:
				break;
			case Gtk.Align.END:
				x_offset -= Math.round (dynamic_animation_offset);
				break;
			case Gtk.Align.FILL:
				switch (position_manager.ItemsAlignment) {
				default:
				case Gtk.Align.FILL:
				case Gtk.Align.CENTER:
					x_offset -= Math.round (dynamic_animation_offset / 2.0);
					break;
				case Gtk.Align.START:
					break;
				case Gtk.Align.END:
					x_offset -= Math.round (dynamic_animation_offset);
					break;
				}
				break;
			}
			
			if (x_offset == 0.0)
				return;
			
			draw_values.map_iterator ().foreach ((i, val) => {
				val.move_right (position, x_offset);
				return true;
			});
		}
		
		inline Surface get_item_surface (DockItem item, int icon_size)
		{
			var private_icon_surface = item.get_surface (icon_size, icon_size, item_buffer);
			if (!screen_is_composited)
				return private_icon_surface;
			
			// FIXME There is probably a nicer way to accomplish this
			// Check if the underlying cache returned a marked surface and if needed
			// request another draw with the currently assumed largest required size
			string? drawing_status;
			unowned PositionManager position_manager = controller.position_manager;
			var max_icon_size = position_manager.ZoomIconSize * window_scale_factor;
			if (icon_size < max_icon_size
				&& ((drawing_status = private_icon_surface.steal_qdata<string> (quark_surface_stats)) != null
				&& drawing_status == SURFACE_STATS_DRAWING_TIME_EXCEEDED))
				item.get_surface (max_icon_size, max_icon_size, item_buffer);
			
			return private_icon_surface;
		}
		
		void draw_item (Cairo.Context cr, DockItem item, DockItemDrawValue draw_value, int64 frame_time)
		{
			unowned WindowCardDockItem? card = (item as WindowCardDockItem);
			if (card != null) {
				draw_window_card (cr, card, draw_value, frame_time);
				return;
			}

			unowned PositionManager position_manager = controller.position_manager;
			unowned SeparatorDockItem? separator = (item as SeparatorDockItem);
			if (separator != null)
				separator.set_horizontal_orientation (position_manager.is_horizontal_dock ());
			var icon_size = (int) draw_value.icon_size * window_scale_factor;
			var position = position_manager.Position;
			
			// load the icon
#if BENCHMARK
			var start = new DateTime.now_local ();
#endif
			var icon_surface = get_item_surface (item, icon_size).copy ();
			unowned Cairo.Context icon_cr = icon_surface.Context;
			
			Surface? icon_overlay_surface = null;
			if (item.CountVisible || item.ProgressVisible)
				icon_overlay_surface = item.get_foreground_surface (icon_size, icon_size, item_buffer, (DrawDataFunc<DockItem>) draw_item_foreground);
			
			if (icon_overlay_surface != null) {
				icon_cr.set_source_surface (icon_overlay_surface.Internal, 0, 0);
				icon_cr.paint ();
			}
			
#if BENCHMARK
			var end = new DateTime.now_local ();
			benchmark.add ("	item.get_surface time - %f ms".printf (end.difference (start) / 1000.0));
#endif
			
			// lighten the icon
			if (draw_value.lighten > 0) {
				icon_cr.set_operator (Cairo.Operator.ADD);
				icon_cr.paint_with_alpha (draw_value.lighten);
				icon_cr.set_operator (Cairo.Operator.OVER);
			}
			
			// darken the icon
			if (draw_value.darken > 0) {
				icon_cr.rectangle (0, 0, icon_surface.Width, icon_surface.Height);
				icon_cr.set_source_rgba (0, 0, 0, draw_value.darken);
				icon_cr.set_operator (Cairo.Operator.ATOP);
				icon_cr.fill ();
				icon_cr.set_operator (Cairo.Operator.OVER);
			}
			
			// draw active glow
			var active_time = int64.max (0LL, frame_time - item.LastActive);
			var opacity = double.min (1, active_time / (double) (theme.ActiveTime * 1000));
			if ((item.State & ItemState.ACTIVE) == 0)
				opacity = 1 - opacity;
			if (opacity > 0) {
				theme.draw_active_glow (item_buffer, background_rect, draw_value.background_region, item.AverageIconColor, opacity, position);
			}
			
			// draw the icon
			if (window_scale_factor > 1) {
				cr.save ();
				cr.scale (1.0 / window_scale_factor, 1.0 / window_scale_factor);
			}
			var draw_region = draw_value.draw_region;
			cr.set_source_surface (icon_surface.Internal, draw_region.x * window_scale_factor, draw_region.y * window_scale_factor);
			if (draw_value.opacity < 1.0)
				cr.paint_with_alpha (draw_value.opacity);
			else
				cr.paint ();
			if (window_scale_factor > 1)
				cr.restore ();
			
			// draw indicators
			if (draw_value.show_indicator && item.Indicator != IndicatorState.NONE)
				draw_indicator_state (cr, draw_value.hover_region, item.Indicator, item.State);
		}

		static Pango.FontDescription? cached_font_title = null;
		static Pango.FontDescription? cached_font_sub = null;

		void draw_window_card (Cairo.Context cr, WindowCardDockItem card, DockItemDrawValue draw_value, int64 frame_time)
		{
			var rect = draw_value.draw_region;
			if (rect.width <= 0 || rect.height <= 0)
				return;

			bool is_horizontal = controller.position_manager.is_horizontal_dock ();
			double card_x = rect.x + 2.0;
			double card_y = rect.y + 4.0;
			double card_w = rect.width - 4.0;
			double card_h = rect.height - 8.0;
			if (card_w < 6.0 || card_h <= 0)
				return;

			bool is_hovered = (controller.window != null && controller.window.HoveredItem == card);
			double card_opacity = draw_value.opacity.clamp (0.0, 1.0);

			if (!is_horizontal) {
				// Vertical Dock Mode: Compact Rounded Square Tile (Centered Icon + Accent Dot)
				card_x = rect.x + 3.0;
				card_y = rect.y + 3.0;
				card_w = rect.width - 6.0;
				card_h = rect.height - 6.0;
				double card_r = 8.0;
				card_r = card_r.clamp (0.0, double.min (card_w / 2.0, card_h / 2.0));

				cr.save ();
				Theme.draw_rounded_rect (cr, card_x, card_y, card_w, card_h, card_r, card_r, 0.0);

				if (is_hovered) {
					cr.set_source_rgba (36.0 / 255.0, 42.0 / 255.0, 56.0 / 255.0, 0.98 * card_opacity);
				} else {
					cr.set_source_rgba (28.0 / 255.0, 32.0 / 255.0, 42.0 / 255.0, 0.95 * card_opacity);
				}
				cr.fill_preserve ();

				if (is_hovered) {
					cr.set_source_rgba (249.0 / 255.0, 115.0 / 255.0, 22.0 / 255.0, 0.50 * card_opacity);
				} else {
					cr.set_source_rgba (1.0, 1.0, 1.0, 0.12 * card_opacity);
				}
				cr.set_line_width (1.0);
				cr.stroke ();

				// Draw crisp centered application icon
				if (card.OwnerItem != null) {
					int vert_icon_size = (int) double.min (26.0, card_w - 10.0);
					var icon_surface = get_item_surface (card.OwnerItem, vert_icon_size * window_scale_factor);
					if (icon_surface != null) {
						cr.save ();
						double ic_x = card_x + (card_w - vert_icon_size) / 2.0;
						double ic_y = card_y + (card_h - vert_icon_size) / 2.0;
						if (window_scale_factor > 1) {
							cr.scale (1.0 / window_scale_factor, 1.0 / window_scale_factor);
							cr.set_source_surface (icon_surface.Internal,
								ic_x * window_scale_factor,
								ic_y * window_scale_factor);
						} else {
							cr.set_source_surface (icon_surface.Internal, ic_x, ic_y);
						}
						if (card_opacity < 1.0)
							cr.paint_with_alpha (card_opacity);
						else
							cr.paint ();
						cr.restore ();
					}
				}

				if (is_hovered) {
					double dot_r = 2.0;
					cr.arc (card_x + card_w / 2.0, card_y + card_h - 4.0, dot_r, 0, 2 * Math.PI);
					cr.set_source_rgba (249.0 / 255.0, 115.0 / 255.0, 22.0 / 255.0, 0.90 * card_opacity);
					cr.fill ();
				}

				cr.restore ();
				return;
			}

			// Horizontal Dock Mode (Standard Elegant Capsule Card)
			double card_r = 7.0;
			card_r = card_r.clamp (0.0, double.min (card_w / 2.0, card_h / 2.0));

			cr.save ();

			// 1. Draw 7px rounded rectangle base
			Theme.draw_rounded_rect (cr, card_x, card_y, card_w, card_h, card_r, card_r, 0.0);

			if (is_hovered) {
				cr.set_source_rgba (36.0 / 255.0, 42.0 / 255.0, 56.0 / 255.0, 0.98 * card_opacity);
			} else {
				cr.set_source_rgba (28.0 / 255.0, 32.0 / 255.0, 42.0 / 255.0, 0.95 * card_opacity);
			}
			cr.fill_preserve ();

			// 2. Delicate hairline border: subtle light border, or warm amber/orange highlight on hover
			if (is_hovered) {
				cr.set_source_rgba (249.0 / 255.0, 115.0 / 255.0, 22.0 / 255.0, 0.50 * card_opacity);
			} else {
				cr.set_source_rgba (1.0, 1.0, 1.0, 0.12 * card_opacity);
			}
			cr.set_line_width (1.0);
			cr.stroke ();

			// Clip contents to card bounds
			Theme.draw_rounded_rect (cr, card_x, card_y, card_w, card_h, card_r, card_r, 0.0);
			cr.clip ();

			// 3. Draw left circular backdrop
			double circle_r = 14.0;
			double circle_cx = card_x + 8.0 + circle_r;
			double circle_cy = card_y + card_h / 2.0;

			cr.arc (circle_cx, circle_cy, circle_r, 0, 2 * Math.PI);
			cr.set_source_rgba (1.0, 1.0, 1.0, 0.10 * card_opacity);
			cr.fill ();

			// 4. Draw application icon centered in the circle
			if (card.OwnerItem != null) {
				int small_icon_size = 18;
				var icon_surface = get_item_surface (card.OwnerItem, small_icon_size * window_scale_factor);
				if (icon_surface != null) {
					cr.save ();
					if (window_scale_factor > 1) {
						cr.scale (1.0 / window_scale_factor, 1.0 / window_scale_factor);
						cr.set_source_surface (icon_surface.Internal,
							(circle_cx - small_icon_size / 2.0) * window_scale_factor,
							(circle_cy - small_icon_size / 2.0) * window_scale_factor);
					} else {
						cr.set_source_surface (icon_surface.Internal,
							circle_cx - small_icon_size / 2.0,
							circle_cy - small_icon_size / 2.0);
					}
					if (card_opacity < 1.0)
						cr.paint_with_alpha (card_opacity);
					else
						cr.paint ();
					cr.restore ();
				}
			}

			// 5. Two lines of typography (slate muted title + bold crisp caption)
			double text_x = circle_cx + circle_r + 8.0;
			double text_w = (card_x + card_w - 10.0) - text_x;
			if (text_w > 20) {
				if (cached_font_title == null)
					cached_font_title = Pango.FontDescription.from_string ("Sans 8.5");
				if (cached_font_sub == null)
					cached_font_sub = Pango.FontDescription.from_string ("Sans Bold 9.5");

				// Line 1: Primary title (#94a3b8)
				var main_title = card.AppTitle;
				if (card.OutputName.length > 0)
					main_title = "%s · %s".printf (card.AppTitle, card.OutputName);

				var layout_title = Pango.cairo_create_layout (cr);
				layout_title.set_font_description (cached_font_title);
				layout_title.set_text (main_title, -1);
				layout_title.set_width ((int) (text_w * Pango.SCALE));
				layout_title.set_ellipsize (Pango.EllipsizeMode.END);

				cr.set_source_rgba (148.0 / 255.0, 163.0 / 255.0, 184.0 / 255.0, 0.92 * card_opacity);
				cr.move_to (text_x, card_y + card_h * 0.16);
				Pango.cairo_show_layout (cr, layout_title);

				// Line 2: Caption in bold bright white (#f8fafc)
				var sub_title = card.WindowCaption;
				if (sub_title.length == 0)
					sub_title = card.AppTitle;

				var layout_sub = Pango.cairo_create_layout (cr);
				layout_sub.set_font_description (cached_font_sub);
				layout_sub.set_text (sub_title, -1);
				layout_sub.set_width ((int) (text_w * Pango.SCALE));
				layout_sub.set_ellipsize (Pango.EllipsizeMode.END);

				cr.set_source_rgba (248.0 / 255.0, 250.0 / 255.0, 252.0 / 255.0, 0.98 * card_opacity);
				cr.move_to (text_x, card_y + card_h * 0.50);
				Pango.cairo_show_layout (cr, layout_sub);
			}

			cr.restore ();
		}
		
		void draw_item_shadow (Cairo.Context cr, DockItem item, DockItemDrawValue draw_value)
		{
			if (item is WindowCardDockItem)
				return;

			unowned PositionManager position_manager = controller.position_manager;
			var shadow_size = position_manager.IconShadowSize;
			// Inflate size to fit shadow
			var icon_size = (int) (draw_value.icon_size + 2 * shadow_size) * window_scale_factor;
			
			// load and draw the icon shadow
			Surface? icon_shadow_surface = null;
			if (shadow_size > 0)
				icon_shadow_surface = item.get_background_surface (icon_size, icon_size, item_buffer, (DrawDataFunc<DockItem>) draw_item_background);
			
			if (icon_shadow_surface != null) {
				if (window_scale_factor > 1) {
					cr.save ();
					cr.scale (1.0 / window_scale_factor, 1.0 / window_scale_factor);
				}
				var draw_region = draw_value.draw_region;
				cr.set_operator (Cairo.Operator.OVER);
				cr.set_source_surface (icon_shadow_surface.Internal, (draw_region.x - shadow_size) * window_scale_factor, (draw_region.y - shadow_size) * window_scale_factor);
				if (draw_value.opacity < 1.0)
					cr.paint_with_alpha (draw_value.opacity);
				else
					cr.paint ();
				if (window_scale_factor > 1)
					cr.restore ();
			}
		}
		
		[CCode (instance_pos = -1)]
		Surface draw_item_foreground (int width, int height, Surface model, DockItem item)
		{
			Logger.verbose ("DockItem.draw_item_overlay (width = %i, height = %i)", width, height);
			var surface = new Surface.with_surface (width, height, model);
			
			var icon_size = int.min (width, height);
			var urgent_color = theme.BadgeColor;
			if (urgent_color.equal ({0.0, 0.0, 0.0, 0.0})) {
				urgent_color = get_styled_color ();
				urgent_color.add_hue (theme.UrgentHueShift);
			}
			
			// draw item's count
			if (item.CountVisible)
				theme.draw_item_count (surface, icon_size, urgent_color, item.Count);
			
			// draw item's progress
			if (item.ProgressVisible)
				theme.draw_item_progress (surface, icon_size, urgent_color, item.Progress);
			
			return surface;
		}
		
		[CCode (instance_pos = -1)]
		Surface draw_item_background (int width, int height, Surface model, DockItem item)
		{
			unowned PositionManager position_manager = controller.position_manager;
			var shadow_size = position_manager.IconShadowSize * window_scale_factor;
			
			var draw_value = position_manager.get_draw_value_for_item (item);
			var icon_size = (int) draw_value.icon_size * window_scale_factor;
			var icon_surface = item.get_surface (icon_size, icon_size, model);
			
			Logger.verbose ("DockItem.draw_icon_with_shadow (width = %i, height = %i, shadow_size = %i)", width, height, shadow_size);
			var surface = new Surface.with_surface (width, height, model);
			unowned Cairo.Context cr = surface.Context;
			var shadow_surface = icon_surface.create_mask (0.4, null);
			
			var xoffset = 0, yoffset = 0;
			switch (position_manager.Position) {
			default:
			case Gtk.PositionType.BOTTOM:
				yoffset = -shadow_size / 4;
				break;
			case Gtk.PositionType.TOP:
				yoffset = shadow_size / 4;
				break;
			case Gtk.PositionType.LEFT:
				xoffset = shadow_size / 4;
				break;
			case Gtk.PositionType.RIGHT:
				xoffset = -shadow_size / 4;
				break;
			}
			
			cr.set_source_surface (shadow_surface.Internal, shadow_size + xoffset, shadow_size + yoffset);
			cr.paint_with_alpha (0.44);
			surface.gaussian_blur (shadow_size);
			
			return surface;
		}
		
		void draw_indicator_state (Cairo.Context cr, Gdk.Rectangle item_rect, IndicatorState indicator, ItemState item_state)
		{
			if (indicator == IndicatorState.NONE)
				return;

			unowned PositionManager position_manager = controller.position_manager;
			bool is_urgent = (item_state & ItemState.URGENT) != 0;
			double pill_h = 3.0;
			double pill_r = 1.5;

			cr.save ();
			if (is_urgent) {
				cr.set_source_rgba (1.0, 0.35, 0.18, 0.95);
			} else {
				if (theme != null && theme.is_light ()) {
					cr.set_source_rgba (0.16, 0.18, 0.24, 0.85);
				} else {
					cr.set_source_rgba (0.88, 0.90, 0.94, 0.85);
				}
			}

			if (position_manager.is_horizontal_dock ()) {
				double item_cx = item_rect.x + item_rect.width / 2.0;
				double pill_y = (position_manager.Position == Gtk.PositionType.BOTTOM) ? (item_buffer.Height - 5.5) : 2.5;

				if (indicator == IndicatorState.SINGLE) {
					double pill_w = 11.0;
					double pill_x = item_cx - pill_w / 2.0;
					Theme.draw_rounded_rect (cr, pill_x, pill_y, pill_w, pill_h, pill_r, pill_r, 0.0);
					cr.fill ();
				} else {
					double seg_w = 5.0;
					double gap = 2.5;
					double total_w = seg_w * 2.0 + gap;
					double left_x = item_cx - total_w / 2.0;
					Theme.draw_rounded_rect (cr, left_x, pill_y, seg_w, pill_h, pill_r, pill_r, 0.0);
					cr.fill ();
					Theme.draw_rounded_rect (cr, left_x + seg_w + gap, pill_y, seg_w, pill_h, pill_r, pill_r, 0.0);
					cr.fill ();
				}
			} else {
				double item_cy = item_rect.y + item_rect.height / 2.0;
				double pill_x = (position_manager.Position == Gtk.PositionType.RIGHT) ? (item_buffer.Width - 5.5) : 2.5;

				if (indicator == IndicatorState.SINGLE) {
					double pill_w = 11.0;
					double py = item_cy - pill_w / 2.0;
					Theme.draw_rounded_rect (cr, pill_x, py, pill_h, pill_w, pill_r, pill_r, 0.0);
					cr.fill ();
				} else {
					double seg_w = 5.0;
					double gap = 2.5;
					double total_w = seg_w * 2.0 + gap;
					double top_y = item_cy - total_w / 2.0;
					Theme.draw_rounded_rect (cr, pill_x, top_y, pill_h, seg_w, pill_r, pill_r, 0.0);
					cr.fill ();
					Theme.draw_rounded_rect (cr, pill_x, top_y + seg_w + gap, pill_h, seg_w, pill_r, pill_r, 0.0);
					cr.fill ();
				}
			}
			cr.restore ();
		}
		
		void draw_urgent_glow (DockItem item, Cairo.Context cr, int64 frame_time)
		{
			if ((item.State & ItemState.URGENT) == 0)
				return;
			
			var diff = int64.max (0LL, frame_time - item.LastUrgent);
			if (diff >= theme.GlowTime * 1000)
				return;
			
			unowned PositionManager position_manager = controller.position_manager;
			var x_offset = 0, y_offset = 0;
			
			if (urgent_glow_buffer == null) {
				var urgent_color = get_styled_color ();
				urgent_color.add_hue (theme.UrgentHueShift);
				urgent_color.set_sat (1.0);
				urgent_glow_buffer = theme.create_urgent_glow (position_manager.GlowSize, urgent_color, main_buffer);
			}
			
			position_manager.get_urgent_glow_position (item, out x_offset, out y_offset);
			
			cr.set_source_surface (urgent_glow_buffer.Internal, x_offset, y_offset);
			var opacity = 0.2 + (0.75 * (Math.sin (diff / (double) (theme.GlowPulseTime * 1000) * 2 * Math.PI) + 1) / 2);
			cr.paint_with_alpha (opacity);
		}
		
		Color get_styled_color ()
		{
			unowned Gtk.StyleContext context = theme.get_style_context ();
			Gdk.RGBA styled_rgba;
			if (!context.lookup_color ("theme_selected_bg_color", out styled_rgba))
				context.get (context.get_state (), "background-color", out styled_rgba, null);
			var color = (Color) styled_rgba;
			color.set_min_val (90 / (double) uint16.MAX);
			return color;
		}
		
		void hidden_changed ()
		{
			force_frame_time_update ();
			var now = frame_time;
			var diff = now - last_hide;
			var time = (theme.FadeOpacity == 1.0 ? theme.HideTime : theme.FadeTime) * 1000;
			
			if (diff < time)
				last_hide = now + (diff - time);
			else
				last_hide = now;
			
			controller.position_manager.update_dock_position ();
			controller.window.update_size_and_position ();
			controller.window.update_icon_regions ();
			
			animated_draw ();
		}
		
		void hovered_changed ()
		{
			force_frame_time_update ();
			var now = frame_time;
			var diff = now - last_hovered_changed;
			var time = DOCK_ZOOM_DURATION * 1000;
			
			if (diff < time)
				last_hovered_changed = now + (diff - time);
			else
				last_hovered_changed = now;
			
			animated_draw ();
		}
		
		public void update_local_cursor (int x, int y)
		{
			Gdk.Point new_cursor = { x, y };
			if (local_cursor == new_cursor)
				return;
			
			local_cursor = new_cursor;
			
			if (screen_is_composited) {
				zoom_changed = true;
				animated_draw ();
			}
		}
		
		public void animate_items (Gee.List<DockElement> elements)
		{
			if (!screen_is_composited)
				return;
			
			foreach (var element in elements) {
				DockItem? item = (element as DockItem);
				if (item != null && !(item is SeparatorDockItem) && !(item is WindowCardDockItem))
					transient_items.add (item);
			}
			
			if (transient_items.size > 0)
				animated_draw ();
		}
		
		void draw_scroll_edge_indicators (Cairo.Context cr, Gdk.Rectangle rect)
		{
			unowned PositionManager pm = controller.position_manager;
			double fade_w = 42.0;

			// Left edge gradient when scroll_offset > 2
			if (pm.scroll_offset > 2.0) {
				cr.save ();
				var pat = new Cairo.Pattern.linear (rect.x, 0, rect.x + fade_w, 0);
				pat.add_color_stop_rgba (0.0, theme.FillEndColor.red, theme.FillEndColor.green, theme.FillEndColor.blue, 0.90);
				pat.add_color_stop_rgba (1.0, theme.FillEndColor.red, theme.FillEndColor.green, theme.FillEndColor.blue, 0.0);
				cr.set_source (pat);
				cr.rectangle (rect.x, rect.y, fade_w, rect.height);
				cr.fill ();

				// Subtle glow indicator chevron "<"
				cr.set_source_rgba (1.0, 1.0, 1.0, 0.55);
				cr.set_line_width (2.0);
				cr.move_to (rect.x + 16, rect.y + rect.height / 2.0 - 6);
				cr.line_to (rect.x + 10, rect.y + rect.height / 2.0);
				cr.line_to (rect.x + 16, rect.y + rect.height / 2.0 + 6);
				cr.stroke ();
				cr.restore ();
			}

			// Right edge gradient when scroll_offset < max_scroll_offset - 2
			if (pm.scroll_offset < pm.max_scroll_offset - 2.0) {
				cr.save ();
				var pat = new Cairo.Pattern.linear (rect.x + rect.width - fade_w, 0, rect.x + rect.width, 0);
				pat.add_color_stop_rgba (0.0, theme.FillEndColor.red, theme.FillEndColor.green, theme.FillEndColor.blue, 0.0);
				pat.add_color_stop_rgba (1.0, theme.FillEndColor.red, theme.FillEndColor.green, theme.FillEndColor.blue, 0.90);
				cr.set_source (pat);
				cr.rectangle (rect.x + rect.width - fade_w, rect.y, fade_w, rect.height);
				cr.fill ();

				// Subtle glow indicator chevron ">"
				cr.set_source_rgba (1.0, 1.0, 1.0, 0.55);
				cr.set_line_width (2.0);
				cr.move_to (rect.x + rect.width - 16, rect.y + rect.height / 2.0 - 6);
				cr.line_to (rect.x + rect.width - 10, rect.y + rect.height / 2.0);
				cr.line_to (rect.x + rect.width - 16, rect.y + rect.height / 2.0 + 6);
				cr.stroke ();
				cr.restore ();
			}
		}

		/**
		 * {@inheritDoc}
		 */
		protected override bool animation_needed (int64 frame_time)
		{
			if (controller.position_manager.is_scrolling ())
				return true;

			if (ApplicationDockItem.is_animating_cards ())
				return true;

			if (zoom_changed) {
				//FIXME reset at a better place
				zoom_changed = false;
				return true;
			}
			
			if (frame_time - last_hovered_changed <= DOCK_ZOOM_DURATION * 1000)
				return true;
			
			if (theme.FadeOpacity == 1.0) {
				if (frame_time - last_hide <= theme.HideTime * 1000)
					return true;
			} else {
				if (frame_time - last_hide <= theme.FadeTime * 1000)
					return true;
			}
			
			if (transient_items.size > 0)
				return true;
			
			foreach (var item in current_items)
				if (item_animation_needed (item, frame_time))
					return true;
			
			return false;
		}

		protected override void animation_finished ()
		{
			controller.window.set_input_mask ();
		}

		inline bool item_animation_needed (DockItem item, int64 render_time)
		{
			if (item.ClickedAnimation != AnimationType.NONE
				&& render_time - item.LastClicked <= (item.ClickedAnimation == AnimationType.BOUNCE ? theme.LaunchBounceTime : theme.ClickTime) * 1000)
				return true;
			if (item.HoveredAnimation != AnimationType.NONE
				&& render_time - item.LastHovered <= ITEM_HOVER_DURATION * 1000)
				return true;
			if (item.ScrolledAnimation != AnimationType.NONE
				&& render_time - item.LastScrolled <= ITEM_SCROLL_DURATION * 1000)
				return true;
			if (render_time - item.LastActive <= theme.ActiveTime * 1000)
				return true;
			if (show_notifications && (item.State & ItemState.URGENT) != 0)
				return true;
			if (render_time - item.LastMove <= theme.ItemMoveTime * 1000)
				return true;
			if (item is WindowCardDockItem) {
				var card = (WindowCardDockItem) item;
				int64 dur = (int64) WindowCardDockItem.CARD_ANIM_TIME_MS * 1000;
				if (card.RemoveTime > 0 && render_time - card.RemoveTime <= dur)
					return true;
				if (card.AddTime > 0 && render_time - card.AddTime <= dur)
					return true;
			}
			if (render_time - item.LastValid <= ITEM_INVALID_DURATION * 1000)
				return true;
			
			return false;
		}
		
		static int compare_dock_item_position (DockItem i1, DockItem i2)
		{
			if (i1 == i2)
				return 0;

			var p_i1 = i1.Position;
			var p_i2 = i2.Position;
			
			if (p_i1 > p_i2)
				return 1;
			
			if (p_i1 < p_i2)
				return -1;
			
			if (i1.RemoveTime > i2.RemoveTime)
				return -1;
			if (i1.RemoveTime < i2.RemoveTime)
				return 1;
			
			return 0;
		}
		
		static double easing_bounce (double t, double d, double n)
			requires (t >= 0.0 && d > 0.0 && n >= 1.0)
			requires (t <= d)
		{
			var p = t / d;
			return Math.fabs (Math.sin (n * Math.PI * p) * double.min (1.0, (1.0 - p) * (2.0 * n) / (2.0 * n - 1.0)));
		}
		
		static unowned string cairo_surface_type_to_string (Cairo.SurfaceType type)
		{
			unowned string result;
			
			switch (type) {
			case Cairo.SurfaceType.IMAGE: result = "IMAGE"; break;
			case Cairo.SurfaceType.PDF: result = "PDF"; break;
			case Cairo.SurfaceType.PS: result = "PS"; break;
			case Cairo.SurfaceType.XLIB: result = "XLIB"; break;
			case Cairo.SurfaceType.XCB: result = "XCB"; break;
			case Cairo.SurfaceType.GLITZ: result = "GLITZ"; break;
			case Cairo.SurfaceType.QUARTZ: result = "QUARTZ"; break;
			case Cairo.SurfaceType.WIN32: result = "WIN32"; break;
			case Cairo.SurfaceType.BEOS: result = "BEOS"; break;
			case Cairo.SurfaceType.DIRECTFB: result = "DIRECTFB"; break;
			case Cairo.SurfaceType.SVG: result = "SVG"; break;
			case Cairo.SurfaceType.OS2: result = "OS2"; break;
			case Cairo.SurfaceType.WIN32_PRINTING: result = "WIN32_PRINTING"; break;
			case Cairo.SurfaceType.QUARTZ_IMAGE: result = "QUARTZ_IMAGE"; break;
			case Cairo.SurfaceType.SCRIPT: result = "SCRIPT"; break;
			case Cairo.SurfaceType.QT: result = "QT"; break;
			case Cairo.SurfaceType.RECORDING: result = "RECORDING"; break;
			case Cairo.SurfaceType.VG: result = "VG"; break;
			case Cairo.SurfaceType.GL: result = "GL"; break;
			case Cairo.SurfaceType.DRM: result = "DRM"; break;
			case Cairo.SurfaceType.TEE: result = "TEE"; break;
			case Cairo.SurfaceType.XML: result = "XML"; break;
			case Cairo.SurfaceType.SKIA: result = "SKIA"; break;
			case Cairo.SurfaceType.SUBSURFACE: result = "SUBSURFACE"; break;
			//FIXME Available in cairo since 1.12
			//case Cairo.SurfaceType.COGL: result = "COGL"; break;
			default: result = "???"; break;
			}
			
			return result;
		}
	}
}
