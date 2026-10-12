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
	public class HelpWindow : Gtk.Window
	{
		Gtk.CssProvider? css_provider = null;
		Gdk.Screen? css_screen = null;

		~HelpWindow ()
		{
			if (css_screen != null && css_provider != null)
				Gtk.StyleContext.remove_provider_for_screen (css_screen, css_provider);
		}

		public HelpWindow ()
		{
			set_title (_("Wayplank Shortcuts & Gestures"));
			set_role ("help");
			set_decorated (true);
			set_destroy_with_parent (true);
			set_position (Gtk.WindowPosition.CENTER);
			set_default_size (620, 500);
			resizable = false;
			set_type_hint (Gdk.WindowTypeHint.DIALOG);
			set_keep_above (true);
			set_focus_on_map (true);
			icon_name = "help-browser";

			// Stack for multi-page categories
			var stack = new Gtk.Stack ();
			stack.set_transition_type (Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
			stack.set_transition_duration (200);

			// Page 1: Mouse Actions
			var grid_mouse = create_shortcuts_grid ();
			add_shortcut_row (grid_mouse, 0, _("Left Click"), _("Launch application, or activate / cycle open windows"));
			add_shortcut_row (grid_mouse, 1, _("Middle Click (or Ctrl + Left)"), _("Force launch a NEW instance of the application"));
			add_shortcut_row (grid_mouse, 2, _("Right Click on Any Item"), _("Open context menu (Quicklists, Keep in Dock, Change Icon, Shortcuts & Gestures, Preferences, Quit)"));
			add_shortcut_row (grid_mouse, 3, _("Mouse Scroll on App"), _("Cycle between all open windows of this application"));
			add_shortcut_row (grid_mouse, 4, _("Shift + Left Click"), _("Focus the next open window of this application"));
			add_shortcut_row (grid_mouse, 5, _("Left Click on Folder Drawer"), _("Open dark-themed categorized smart application menu"));
			add_shortcut_row (grid_mouse, 6, _("Preferences Icon (Accordion)"), _("Hover or click to toggle docklet drawer; directional indicators (▸ / ◂ / ▾ / ▴) show state"));
			add_shortcut_row (grid_mouse, 7, _("Accordion Auto-Retention"), _("Drawer stays open during menus & dialogs; full countdown (0.5s–20s) restarts on close"));
			add_shortcut_row (grid_mouse, 8, _("Mouse Scroll on Brightness"), _("Adjust display brightness with multi-monitor hardware sync"));
			add_shortcut_row (grid_mouse, 9, _("Mouse Scroll on Volume"), _("Adjust master audio volume up or down"));
			add_shortcut_row (grid_mouse, 10, _("Middle Click on MPRIS"), _("Play or pause media playback"));
			add_shortcut_row (grid_mouse, 11, _("Mouse Scroll on MPRIS"), _("Skip to next or previous media track"));
			stack.add_titled (create_page (_("Interactions and gestures on application icons, drawers and docklets"), grid_mouse), "mouse", _("Mouse Actions"));

			// Page 2: Drag & Drop & Organization
			var grid_drag = create_shortcuts_grid ();
			add_shortcut_row (grid_drag, 0, _("Drag icon along dock (Free Mode)"), _("Freely reorder launchers, docklets, and folders anywhere on the dock"));
			add_shortcut_row (grid_drag, 1, _("Drag icon along dock (Categorized)"), _("Reorder strictly within category bounds; Preferences anchor stays locked"));
			add_shortcut_row (grid_drag, 2, _("Drag icon off dock"), _("Unpin / remove launcher from dock (with smoke animation)"));
			add_shortcut_row (grid_drag, 3, _("Drop file on app icon"), _("Open the dropped file directly with that application"));
			add_shortcut_row (grid_drag, 4, _("Drop .desktop or folder"), _("Pin a new application or folder drawer to the dock"));
			add_shortcut_row (grid_drag, 5, _("Align by Type (Preferences)"), _("One-shot sort in Free mode: [Plank] -> [Folders] -> [Docklets] -> [Apps] -> [Trash]"));
			stack.add_titled (create_page (_("Organizing, pinning, reordering and interacting with dock items"), grid_drag), "drag", _("Drag & Drop"));

			// Page 3: Shortcuts & Tools
			var grid_tools = create_shortcuts_grid ();
			add_shortcut_row (grid_tools, 0, _("Ctrl + Mouse Scroll Up"), _("Increase dock icon size dynamically in real-time"));
			add_shortcut_row (grid_tools, 1, _("Ctrl + Mouse Scroll Down"), _("Decrease dock icon size dynamically in real-time"));
			add_shortcut_row (grid_tools, 2, _("Ctrl + Right Click"), _("Open dock preferences menu directly, even over an icon"));
			add_shortcut_row (grid_tools, 3, _("Right Click on space / separator"), _("Open dock preferences menu from any empty dock area or separator"));
			add_shortcut_row (grid_tools, 4, _("Right Click -> Change Icon..."), _("Choose system icon or custom image for any launcher or folder drawer"));
			add_shortcut_row (grid_tools, 5, _("Right Click -> Shortcuts & Gestures"), _("Open this interactive guide directly from any item context menu"));
			add_shortcut_row (grid_tools, 6, _("Ctrl + Alt + Shift + Right Click"), _("Open Developer Tools submenu (inspect launcher, config, theme)"));
			stack.add_titled (create_page (_("Dynamic zoom, universal icons, dock settings and developer tools"), grid_tools), "tools", _("Shortcuts & Tools"));

			// HeaderBar with StackSwitcher spanning full width
			var header = new Gtk.HeaderBar ();
			header.show_close_button = true;

			var switcher = new Gtk.StackSwitcher ();
			switcher.set_stack (stack);
			switcher.set_homogeneous (true);
			switcher.set_hexpand (true);
			switcher.set_halign (Gtk.Align.FILL);
			foreach (var child in switcher.get_children ()) {
				child.hexpand = true;
				child.halign = Gtk.Align.FILL;
			}
			header.set_custom_title (switcher);
			
			css_provider = new Gtk.CssProvider ();
			css_screen = get_screen ();
			try {
				css_provider.load_from_data (
					"headerbar stackswitcher, headerbar .stack-switcher { margin-left: 2px; margin-right: 2px; }\n" +
					"headerbar stackswitcher button, headerbar .stack-switcher button { padding-left: 14px; padding-right: 14px; font-weight: bold; }\n"
				);
				Gtk.StyleContext.add_provider_for_screen (css_screen, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
			} catch (GLib.Error e) {
				warning ("Unable to load help window CSS: %s", e.message);
			}

			header.show_all ();
			set_titlebar (header);

			// Main vertical content layout
			var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
			content.pack_start (stack, true, true, 0);

			content.pack_start (new Gtk.Separator (Gtk.Orientation.HORIZONTAL), false, false, 0);

			// Centered OK Action button (Identical to PreferencesWindow)
			var actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
			actions.set_margin_start (12);
			actions.set_margin_end (12);
			actions.set_margin_top (10);
			actions.set_margin_bottom (12);
			actions.set_halign (Gtk.Align.CENTER);

			var ok_button = new Gtk.Button.with_label (_("OK"));
			ok_button.set_size_request (160, 36);
			ok_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
			ok_button.clicked.connect (() => hide ());
			actions.pack_end (ok_button, false, false, 0);

			content.pack_end (actions, false, false, 0);
			add (content);

			ok_button.set_can_default (true);
			set_default (ok_button);

			// Close on Escape key
			key_press_event.connect ((event) => {
				if (event.keyval == Gdk.Key.Escape) {
					hide ();
					return true;
				}
				return false;
			});

			content.show_all ();
		}

		Gtk.Widget create_page (string subtitle, Gtk.Grid grid)
		{
			var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
			box.set_margin_start (20);
			box.set_margin_end (20);
			box.set_margin_top (18);
			box.set_margin_bottom (18);

			var sub_lbl = new Gtk.Label (subtitle);
			sub_lbl.get_style_context ().add_class ("dim-label");
			sub_lbl.set_xalign (0.0f);
			sub_lbl.set_margin_bottom (12);
			box.pack_start (sub_lbl, false, false, 0);

			box.pack_start (grid, true, true, 0);

			var scrolled = new Gtk.ScrolledWindow (null, null);
			scrolled.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
			scrolled.set_shadow_type (Gtk.ShadowType.NONE);
			scrolled.add (box);

			return scrolled;
		}

		Gtk.Grid create_shortcuts_grid ()
		{
			var grid = new Gtk.Grid ();
			grid.column_spacing = 20;
			grid.row_spacing = 10;
			grid.set_margin_start (6);
			grid.set_margin_end (6);
			grid.set_halign (Gtk.Align.FILL);
			return grid;
		}

		void add_shortcut_row (Gtk.Grid grid, int row, string shortcut, string description)
		{
			var lbl_shortcut = new Gtk.Label (null);
			lbl_shortcut.set_markup ("<tt><b>%s</b></tt>".printf (GLib.Markup.escape_text (shortcut)));
			lbl_shortcut.set_xalign (0.0f);
			lbl_shortcut.set_yalign (0.5f);

			var lbl_desc = new Gtk.Label (description);
			lbl_desc.set_xalign (0.0f);
			lbl_desc.set_yalign (0.5f);
			lbl_desc.set_line_wrap (true);
			lbl_desc.set_hexpand (true);

			grid.attach (lbl_shortcut, 0, row, 1, 1);
			grid.attach (lbl_desc, 1, row, 1, 1);
		}
	}
}
