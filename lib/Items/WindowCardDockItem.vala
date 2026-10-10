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
	 * An interactive pill-shaped window card docked beside an application icon,
	 * displaying primary title with monitor tag and subtitle caption.
	 */
	public class WindowCardDockItem : DockItem
	{
		public string WindowId { get; construct set; }
		public string AppTitle { get; construct set; }
		public string OutputName { get; construct set; }
		public string WindowCaption { get; construct set; }
		public string IconName { get; construct set; }
		public unowned ApplicationDockItem? OwnerItem { get; construct set; }
		public double CardWidth { get; set; default = 220.0; }

		public WindowCardDockItem (string window_id, string app_title, string output_name, string window_caption, string icon_name, ApplicationDockItem owner)
		{
			GLib.Object (
				Prefs: owner != null ? owner.Prefs : null,
				WindowId: window_id,
				AppTitle: app_title,
				OutputName: output_name,
				WindowCaption: window_caption,
				IconName: icon_name,
				OwnerItem: owner
			);
		}

		construct
		{
			Icon = IconName;
			Text = WindowCaption.length > 0 ? WindowCaption : AppTitle;
		}

		public const uint CARD_ANIM_TIME_MS = 250;

		public double get_animation_progress (int64 frame_time, uint move_time_ms = CARD_ANIM_TIME_MS)
		{
			if (frame_time <= 0LL)
				frame_time = GLib.get_monotonic_time ();

			uint dur_ms = move_time_ms > 0 ? uint.min (move_time_ms, CARD_ANIM_TIME_MS) : CARD_ANIM_TIME_MS;
			int64 duration = (int64) dur_ms * 1000;
			if (duration <= 0)
				return 1.0;

			if (RemoveTime > 0) {
				int64 elapsed = int64.max (0LL, frame_time - RemoveTime);
				if (elapsed >= duration)
					return 0.0;
				double t = (double) elapsed / (double) duration;
				double p = (1.0 - t).clamp (0.0, 1.0);
				return p * p * (3.0 - 2.0 * p);
			}

			if (AddTime > 0) {
				int64 elapsed = int64.max (0LL, frame_time - AddTime);
				if (elapsed >= duration)
					return 1.0;
				double t = ((double) elapsed / (double) duration).clamp (0.0, 1.0);
				return t * t * (3.0 - 2.0 * t);
			}

			return 1.0;
		}

		public double get_effective_card_width (int64 frame_time, uint move_time_ms = CARD_ANIM_TIME_MS)
		{
			double progress = get_animation_progress (frame_time, move_time_ms);
			return CardWidth * progress;
		}

		public double get_effective_card_height (int icon_size, int64 frame_time, uint move_time_ms = CARD_ANIM_TIME_MS)
		{
			double progress = get_animation_progress (frame_time, move_time_ms);
			return (double) icon_size * progress;
		}

		public double get_effective_slot_width (int icon_size, int item_padding, int64 frame_time, uint move_time_ms = CARD_ANIM_TIME_MS, bool is_horizontal = true)
		{
			double progress = get_animation_progress (frame_time, move_time_ms);
			double base_slot = is_horizontal ? (CardWidth + item_padding) : (icon_size + item_padding);
			return base_slot * progress;
		}

		public double get_card_slot_width (int icon_size, int item_padding, bool is_horizontal = true)
		{
			return is_horizontal ? (CardWidth + item_padding) : (icon_size + item_padding);
		}

		protected override void draw_icon (Surface surface)
		{
			// WindowCardDockItem is rendered directly in DockRenderer
		}

		protected override AnimationType on_clicked (PopupButton button, Gdk.ModifierType mod, uint32 event_time)
		{
			if (RemoveTime > 0)
				return AnimationType.NONE;

			if (button == PopupButton.LEFT) {
				message ("Wayplank: window card clicked for uuid=%s ('%s')", WindowId, Text);
				WindowControl.queue_command (WindowId, "activate");
				if (OwnerItem != null) {
					OwnerItem.collapse_cards ();
				}
				return AnimationType.NONE;
			}
			return AnimationType.NONE;
		}

		public override Gee.ArrayList<Gtk.MenuItem> get_menu_items ()
		{
			var items = new Gee.ArrayList<Gtk.MenuItem> ();

			var activate_item = create_menu_item (_("Activate"), "window-new", true);
			activate_item.activate.connect (() => {
				WindowControl.queue_command (WindowId, "activate");
				if (OwnerItem != null)
					OwnerItem.collapse_cards ();
			});
			items.add (activate_item);

			var close_item = create_menu_item (_("Close"), "window-close", true);
			close_item.activate.connect (() => {
				WindowControl.queue_command (WindowId, "close");
				if (OwnerItem != null)
					OwnerItem.collapse_cards ();
			});
			items.add (close_item);

			return items;
		}

		public override bool can_be_removed ()
		{
			return false;
		}
	}
}
