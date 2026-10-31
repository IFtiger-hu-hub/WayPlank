# kde-dockbar

> 专为 **KDE Plasma (Wayland)** 量身打造的高性能原生 Dock 栏。

[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](LICENSE)
[![Platform: KDE Plasma Wayland](https://img.shields.io/badge/Desktop-KDE%20Plasma%20Wayland-0057B7.svg)](https://kde.org)
[![Packaging: Native RPM](https://img.shields.io/badge/Package-Fedora%20%7C%20openSUSE-green.svg)](BuildRpm.sh)

---

## 🌟 项目简介

`kde-dockbar` 诞生于对极致轻量与原生融合的追求。

传统或通用的 Wayland Dock（如原始 WayPlank）为了跨桌面兼容 GNOME (Mutter 扩展/DBus 桥接) 与 wlroots (Labwc/Sway 协议桥接)，引入了大量复杂的兼容层、Workarea hack、C 桥接驱动以及繁琐的多合成器检测逻辑。

**`kde-dockbar` 彻底剥离所有非 KDE 杂质**，只专注服务于 **KDE Plasma 桌面环境**：
- **纯粹的 KWin 深度集成**：通过原生 KWin D-Bus 脚本与事件桥接获取精准窗口状态、焦点、虚拟桌面与多窗口管理；
- **原生 GtkLayerShell**：依托 KWin 完善的 Layer Shell 支持，实现零 Hack 的屏幕吸附、独占区（Exclusive Zone）与多显示器管理；
- **KDE 生态优先**：内置 Spectacle 截图、Plasma SystemMonitor 监视、KDE 锁屏/电源与 Breeze 配色融合；
- **极简工程架构**：无任何外部 C 协议垫片或废弃多桌面后端，代码清晰干净，便于二次开发与新特性拓展。

---

## 🚀 快速上手

### 1. 编译依赖 (Fedora / openSUSE / RHEL)

确保系统已安装基本的构建工具与依赖：

**Fedora / RHEL:**
```bash
sudo dnf install vala gtk3-devel gtk-layer-shell-devel libgee-devel json-glib-devel rpm-build
```

**openSUSE:**
```bash
sudo zypper install vala gtk3-devel gtk-layer-shell-devel libgee-devel json-glib-devel rpm-build
```

---

### 2. 编译本地二进制

直接运行一键构建脚本即可完成 GResource 编译与原生二进制生成：

```bash
./BuildBin.sh
```

构建产物位于：`build/kde-dockbar`。

启动运行或调试：
```bash
# 启动运行
./build/kde-dockbar

# 替换当前已运行的 dock 实例并开启调试日志
./build/kde-dockbar -r -d
```

---

### 3. 一键打包 RPM (推荐)

项目自带纯净的 RPM 构建流程，自动生成适配本机的标准 RPM 安装包：

```bash
./BuildRpm.sh
```

构建成功后，直接通过包管理器安装：
```bash
# Fedora:
sudo dnf install build/kde-dockbar-0.1.0-1.x86_64.rpm

# openSUSE:
sudo zypper install build/kde-dockbar-0.1.0-1.x86_64.rpm
```

---

## 🗂️ 目录结构

```text
kde-dockbar/
├── BuildBin.sh             # 原生二进制一键构建脚本
├── BuildRpm.sh             # RPM 自动化打包脚本
├── LICENSE                 # GPL-3.0 许可证
├── README.md               # 项目文档
├── data/                   # 资源文件
│   ├── glib-2.0/schemas/   # GSettings 配置模式定义
│   ├── icons/              # 内置通用应用与状态图标
│   ├── themes/             # 预设主题 (Dark, Light, Transparent 等)
│   ├── docklets/           # 内置 Docklet SVG 矢量图标
│   ├── ui/                 # 首选项配置 GTK UI 描述
│   ├── kde-dockbar.desktop # KDE 自动启动与桌面入口
│   ├── kde-dockbar.svg     # 应用矢量图标
│   └── plank.gresource.xml # GResource 清单
├── include/
│   └── config.h            # 构建与元数据宏定义
├── vapi/                   # Vala 绑定配置 (compat, config)
├── lib/                    # 核心库实现
│   ├── DBus/               # DBus 接口抽象
│   ├── Drawing/            # Cairo 渲染、主题与色彩引擎
│   ├── Factories/          # Item / Docklet 工厂与主控制器基类
│   ├── Items/              # Docklet（音量/CPU/网络/电池/截图/会话等）
│   ├── Services/           # KWinBridge, KWinBackend, WindowControl, Theme 等
│   └── Widgets/            # DockWindow, HoverWindow, Multi-Window Cards 等
└── src/
    └── Main.vala           # 应用程序主入口
```

---

## 🎯 核心特性与快捷操作

- **多窗口预览卡片**：当单个应用拥有多个窗口时，左键点击触发平滑的 Cairo 悬浮预览卡片，支持直接关闭或切换焦点；
- **动态图标缩放**：按住 `Ctrl` + 鼠标滚轮可实时无缝调节 Dock 图标尺寸；
- **KDE 原生截图**：右键截图 Docklet 可选择区域截图、全屏截图、活动窗口或延时截图（无缝调用 Spectacle）；
- **拖拽整理**：
  - 拖拽图标离开 Dock 栏触发烟雾消散（Poof）动画移除；
  - 拖拽调整固定项顺序；
  - 支持将外部文件/网页 URL 拖入应用图标直接打开；
- **智能避让与隐藏**：支持智能避让（Intelligent）、最大化避让（Dodge Maximized）、自动隐藏（Auto Hide）与固定显示；
- **深浅色主题无缝协同**：实时检测 KDE Plasma 主题变化并自动匹配高对比度呈现。

---

## 🤝 鸣谢与致敬

- 基于 [Plank](https://launchpad.net/plank) 与 [WayPlank](https://github.com/sergiomelas/WayPlank) 项目的优秀积淀与架构演进；
- 感谢 KDE 社区对 Wayland 标准与 Layer-Shell 协议的卓越实现。

## Wayland flush-retry (scheme A)

GDK aborts on transient `wl_display_flush` EAGAIN. kde-dockbar loads
`~/.local/lib/kde-dockbar/libwl_flush_retry.so` via `LD_PRELOAD` in the user
systemd unit so flush is polled/retried (~400ms cap) before returning the error.
Details: `lib/flush-retry/README.md`. This only affects kde-dockbar.
