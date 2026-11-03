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
	public class HelpWindow : Gtk.Window
	{
		public static bool is_open { get; private set; default = false; }
		public static HelpWindow? active_instance { get; private set; default = null; }

		Gtk.CssProvider? css_provider = null;
		Gdk.Screen? css_screen = null;

		~HelpWindow ()
		{
			is_open = false;
			if (active_instance == this)
				active_instance = null;
			if (css_screen != null && css_provider != null)
				Gtk.StyleContext.remove_provider_for_screen (css_screen, css_provider);
		}

		public HelpWindow ()
		{
			is_open = true;
			active_instance = this;
			this.show.connect (() => {
				is_open = true;
				active_instance = this;
			});
			this.hide.connect (() => {
				is_open = false;
				if (active_instance == this)
					active_instance = null;
			});
			this.destroy.connect (() => {
				is_open = false;
				if (active_instance == this)
					active_instance = null;
			});

			set_role ("help");
			set_decorated (true);
			set_destroy_with_parent (false);
			set_position (Gtk.WindowPosition.CENTER);
			gravity = Gdk.Gravity.CENTER;
			set_default_size (660, 520);
			resizable = true;
			set_type_hint (Gdk.WindowTypeHint.DIALOG);
			set_skip_taskbar_hint (true);
			set_skip_pager_hint (true);
			set_keep_above (true);
			set_focus_on_map (true);
			icon_name = "plank";

			// Stack for multi-page categories
			var stack = new Gtk.Stack ();
			stack.set_transition_type (Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
			stack.set_transition_duration (200);

			// Page 1: Mouse Actions
			var grid_mouse = create_shortcuts_grid ();
			int r_m = 0;
			add_shortcut_row (grid_mouse, r_m++, "鼠标左键单击", "启动应用；若已在运行，置顶或显示多窗口卡片");
			add_shortcut_row (grid_mouse, r_m++, "左键单击（2个及以上窗口）", _("展开悬浮 Cairo 多窗口平铺卡片与实时缩略图"));
			add_shortcut_row (grid_mouse, r_m++, _("中键单击 (或 Ctrl + 左键)"), "强制启动该应用程序的新实例");
			add_shortcut_row (grid_mouse, r_m++, _("在任何项目上右键单击"), _("打开右键菜单 (最近打开文档、快捷操作列表、固定至 Dock、更改图标、快捷键与手势、首选项)"));
			add_shortcut_row (grid_mouse, r_m++, "在应用图标上滚动滚轮", "依次轮巡切换该应用的所有已打开窗口");
			add_shortcut_row (grid_mouse, r_m++, _("Shift + 左键单击"), _("顺次聚焦该应用的下一个打开窗口"));
			add_shortcut_row (grid_mouse, r_m++, _("左键单击文件夹抽屉"), _("打开深色高质感分类智能应用抽屉"));
			add_shortcut_row (grid_mouse, r_m++, _("首选项图标 (折叠风琴)"), _("悬停或点击展开/折叠插件抽屉；方向指示箭头 (▸ / ◂ / ▾ / ▴) 实时展示抽屉状态"));
			add_shortcut_row (grid_mouse, r_m++, _("折叠抽屉自动保持"), _("菜单与弹窗激活期间抽屉保持常开；弹窗关闭后完整倒计时 (0.5s–20s) 自动重启"));
			add_shortcut_row (grid_mouse, r_m++, _("在亮度图标上滚动滚轮"), _("调节屏幕亮度并支持多显示器硬件同步"));
			add_shortcut_row (grid_mouse, r_m++, _("在音量图标上滚动滚轮"), _("调节系统主音量大小"));
			add_shortcut_row (grid_mouse, r_m++, _("中键单击媒体播放器"), _("播放或暂停多媒体播放"));
			add_shortcut_row (grid_mouse, r_m++, _("在媒体播放器上滚动滚轮"), _("切歌至下一曲或上一曲"));
			stack.add_titled (create_page (_("应用程序图标、抽屉及 Docklet 插件的交互与手势指南"), grid_mouse), "mouse", _("鼠标与手势操作"));

			// Page 2: Drag & Drop & Organization
			var grid_drag = create_shortcuts_grid ();
			int r_d = 0;
			add_shortcut_row (grid_drag, r_d++, _("沿停靠栏拖动图标 (自由排序模式)"), _("在停靠栏任意位置自由拖拽重排启动器、插件和文件夹"));
			add_shortcut_row (grid_drag, r_d++, _("沿停靠栏拖动图标 (分类排序模式)"), _("严格在所属分类界限内重排；首选项锚点始终保持锁定"));
			add_shortcut_row (grid_drag, r_d++, "将图标拖离 Dock 栏", "从 Dock 栏取消固定/移除（触发烟雾消散动画）");
			add_shortcut_row (grid_drag, r_d++, "将文件拖放到应用图标上", "使用该应用程序直接打开拖入的文件");
			add_shortcut_row (grid_drag, r_d++, "将网页 URL 拖放到浏览器图标", _("将 http:// 或 https:// 网址拖放至浏览器图标直接在新标签页中打开"));
			add_shortcut_row (grid_drag, r_d++, "拖拽文件时悬停在应用图标上", _("悬停 500 毫秒自动置顶唤醒目标窗口 (悬停弹窗)"));
			add_shortcut_row (grid_drag, r_d++, _("拖放 .desktop 启动器或文件夹"), "将新应用程序或文件夹抽屉固定到 Dock 栏");
			add_shortcut_row (grid_drag, r_d++, _("按类型对齐 (首选项)"), _("自由模式下一键自动排序: [Plank] -> [文件夹] -> [插件] -> [应用] -> [回收站]"));
			stack.add_titled (create_page (_("停靠栏图标的整理、固定、重排及深度交互"), grid_drag), "drag", _("拖拽交互 (Drag & Drop)"));

			// Page 3: Shortcuts & Tools
			var grid_tools = create_shortcuts_grid ();
			int r_t = 0;
			add_shortcut_row (grid_tools, r_t++, "在 Dock 空白处滚动滚轮", "当容量超出屏幕宽度时平滑滚动 Dock 图标");
			add_shortcut_row (grid_tools, r_t++, "Ctrl + 鼠标滚轮向上", "实时无级放大 Dock 图标尺寸");
			add_shortcut_row (grid_tools, r_t++, "Ctrl + 鼠标滚轮向下", "实时无级缩小 Dock 图标尺寸");
			add_shortcut_row (grid_tools, r_t++, "Ctrl + 右键单击", "即使光标在应用图标上也可直接唤出 Dock 首选项菜单");
			add_shortcut_row (grid_tools, r_t++, _("在底板空白处或分隔线上右键单击"), _("从停靠栏任意空白区域或分隔线上打开首选项设置"));
			add_shortcut_row (grid_tools, r_t++, _("右键单击 -> 更改图标..."), _("为启动器或文件夹抽屉选择系统图标或自定义图像"));
			add_shortcut_row (grid_tools, r_t++, _("右键单击 -> 快捷键与手势"), _("从任意图标右键菜单中快速打开此交互式指南"));
			add_shortcut_row (grid_tools, r_t++, "首选项 -> 主题管理器", _("安装主题压缩包 (.zip, .tar.gz) 并管理自定义停靠栏主题"));
			add_shortcut_row (grid_tools, r_t++, "动态深浅主题自动匹配", "KDE Plasma 切换深色/浅色时自动无缝匹配 Dock 栏主题");
			add_shortcut_row (grid_tools, r_t++, _("Ctrl + Alt + Shift + 右键单击"), "打开开发者工具子菜单（检查启动项、配置与主题信息）");
			stack.add_titled (create_page (_("动态悬浮缩放、超限平滑翻页、实时主题管理器与开发者调试工具"), grid_tools), "tools", _("快捷键与实用工具"));

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
			set_title (_("WayPlank 快捷键与手势指南"));
			header.title = _("WayPlank 快捷键与手势指南");

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

			var ok_button = new Gtk.Button.with_label (_("确定"));
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
