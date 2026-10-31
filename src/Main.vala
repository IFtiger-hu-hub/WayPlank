//
//  Copyright (C) 2011-2012 Robert Dyer, Michal Hruby, Rico Tzschichholz
//  Copyright (C) 2026 Sergio Melas
//  Copyright (C) 2026 史有虎 (IFtiger-hu)
//
//  This file is part of kde-dockbar.
//
//  kde-dockbar is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//

namespace Plank
{
    public static int main (string[] argv)
    {
        PlankCompat.optimize_memory ();

        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (Build.GETTEXT_PACKAGE, Build.DATADIR + "/locale");
        Intl.bind_textdomain_codeset (Build.GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (Build.GETTEXT_PACKAGE);

        bool replace_requested = false;
        for (int i = 1; i < argv.length; i++) {
            if (argv[i] == "--help" || argv[i] == "-h" || argv[i] == "-?") {
                print_clean_help ();
                return 0;
            }
            if (argv[i] == "--version" || argv[i] == "-v" || argv[i] == "-V") {
                print ("kde-dockbar %s\n", Build.VERSION);
                return 0;
            }
            if (argv[i] == "--shortcuts" || argv[i] == "-s" || argv[i] == "--gestures") {
                print_shortcuts_cheatsheet ();
                return 0;
            }
            if (argv[i] == "--replace" || argv[i] == "--reload" || argv[i] == "-r") {
                replace_requested = true;
            }
        }

        if (replace_requested) {
            try {
                Process.spawn_command_line_sync ("killall -q -o 1s -9 kde-dockbar wayplank");
            } catch (Error e) { }
            Thread.usleep (250000);
        }

        Gtk.init (ref argv);

        unowned Gdk.Display? display = Gdk.Display.get_default ();
        if (display == null || display.get_type ().name () != "GdkWaylandDisplay") {
            var dialog = new Gtk.MessageDialog (
                null,
                Gtk.DialogFlags.MODAL,
                Gtk.MessageType.WARNING,
                Gtk.ButtonsType.OK,
                "kde-dockbar is designed exclusively for KDE Plasma Wayland sessions."
            );
            dialog.title = "kde-dockbar - Unsupported Session";
            dialog.run ();
            dialog.destroy ();
            return 1;
        }

        var application = new Plank.Main ();
        Factory.init (application, new ItemFactory ());
        return application.run (argv);
    }

    public class Main : AbstractMain
    {
        public Main ()
        {
            var authors = new string[] {
                    "史有虎 (IFtiger-hu)",
                    "Sergio Melas <sergiomelas@gmail.com>",
                    "Robert Dyer <psybers@gmail.com>",
                    "Rico Tzschichholz <ricotz@ubuntu.com>",
                    "Michal Hruby <michal.mhr@gmail.com>"
                };

            var documenters = new string[] {
                    "史有虎 (IFtiger-hu)",
                    "Sergio Melas <sergiomelas@gmail.com>"
                };

            var artists = new string[] {
                    "Daniel Foré <daniel@elementaryos.org>"
                };

            Object (
                build_data_dir : Build.DATADIR,
                build_pkg_data_dir : Build.PKGDATADIR,
                build_release_name : Build.RELEASE_NAME,
                build_version : Build.VERSION,
                build_version_info : Build.VERSION_INFO,

                program_name : "kde-dockbar",
                exec_name : "kde-dockbar",

                app_copyright : "2026 史有虎 (IFtiger-hu)\nCopyright © 2026 Sergio Melas\nCopyright © 2011-2017 Plank Developers",
                app_dbus : "net.launchpad.plank",
                app_icon : "kde-dockbar",
                app_launcher : "kde-dockbar.desktop",

                main_url : "https://github.com/IFtiger-hu-hub/WayPlank",
                help_url : "https://github.com/IFtiger-hu-hub/WayPlank/issues",
                translate_url : "https://github.com/IFtiger-hu-hub/WayPlank",

                about_authors : authors,
                about_documenters : documenters,
                about_artists : artists,
                about_translators : _("translator-credits"),
                about_license_type : Gtk.License.GPL_3_0
            );
        }
    }

    static void print_clean_help ()
    {
        print ("用法:\n  kde-dockbar [选项…]\n\n");
        print ("帮助选项:\n");
        print ("  -h, --help                显示帮助选项\n");
        print ("  -s, --shortcuts           在终端打印快捷键与鼠标操作说明\n");
        print ("  -v, --version             显示应用程序版本\n\n");
        print ("应用程序选项:\n");
        print ("  -p, --preferences         显示运行中或已启动实例的首选项对话框\n");
        print ("  -r, --replace, --reload   重启并替换当前运行中的 Dock 实例\n");
        print ("  -d, --debug               开启调试日志\n");
        print ("  -V, --verbose             开启详细日志\n");
        print ("  -n, --name=NAME           此 Dock 栏的名称，默认为 \"dock1\"\n\n");
    }

    static void print_shortcuts_cheatsheet ()
    {
        print ("\n=======================================================\n");
        print ("  kde-dockbar — 快捷键、鼠标操作与手势指南\n");
        print ("=======================================================\n\n");
        print ("图标鼠标操作:\n");
        print ("  左键单击                      启动应用；若已运行，置顶或展开多窗口预览卡片\n");
        print ("  中键单击 (或 Ctrl+左键)       强制启动该应用程序的新实例\n");
        print ("  右键单击                      打开上下文菜单 (保持在Dock、更换图标、首选项等)\n");
        print ("  在应用图标上滚动滚轮          依次循环切换该应用的所有已打开窗口\n");
        print ("  悬停 / 点击首选项图标         展开小组件抽屉面板；方向指示器 (▸ / ◂ / ▾ / ▴)\n");
        print ("  抽屉自动保持展开              菜单/对话框打开时保持抽屉不自动关闭\n\n");
        print ("多窗口视觉预览卡片:\n");
        print ("  左键单击 (2个以上窗口)        显示带有实时缩略图的 Cairo 浮动窗口预览卡片\n");
        print ("  卡片左键单击                  将目标窗口置顶并激活焦点\n");
        print ("  关闭按钮 / 中键点击卡片       直接在卡片上关闭目标窗口实例\n");
        print ("  首选项 -> 行为                在多窗口预览卡片与循环轮巡模式间切换\n\n");
        print ("超出滑动与动态缩放:\n");
        print ("  在 Dock 空白处滚动滚轮        当容量超出屏幕宽度时平滑左右/上下滑动\n");
        print ("  Ctrl + 鼠标滚轮向上           实时无级放大 Dock 图标尺寸\n");
        print ("  Ctrl + 鼠标滚轮向下           实时无级缩小 Dock 图标尺寸\n\n");
        print ("拖拽手势:\n");
        print ("  将图标拖离 Dock 栏            取消固定/从 Dock 移除 (触发烟雾消散动画)\n");
        print ("  沿 Dock 栏拖拽图标            重新排列固定图标顺序\n");
        print ("  将文件拖放到应用图标          使用该应用程序直接打开该文件\n");
        print ("  将网址拖放到浏览器图标        将网页链接拖入浏览器在新标签页打开\n");
        print ("  拖拽文件时悬停在图标上        触发弹簧悬停(500ms)并将目标窗口激活到前台\n");
        print ("  拖入 .desktop 文件            将新应用程序固定到 Dock 栏\n\n");
        print ("Dock 控制与主题:\n");
        print ("  右键单击 -> 更换图标          为应用选择系统图标或自定义图像\n");
        print ("  右键单击 -> 快捷键与手势      直接打开可视化快捷键与手势说明窗口\n");
        print ("  Ctrl + 右键单击               直接打开 Dock 栏首选项菜单\n");
        print ("  首选项 -> 主题管理器          通过文件选择器安装主题压缩包 (.zip, .tar.gz)\n");
        print ("  动态深浅主题自动匹配          KDE Plasma 切换深浅主题时自动匹配 Dock 主题\n");
        print ("  Ctrl+Alt+Shift + 右键单击     打开开发者工具子菜单 (检查启动器、配置、主题)\n\n");
    }
}
