# Wayplank V0.5.4 Detailed Technical Changelog

Release Milestone: **V0.5.4** (Drag & Drop Payload Delivery, Spring-Loaded Window Activation, Drop Pill Capsule Hint & Side Dock Zoom Clipping Fix)  
Release Date: 2026-10-10  
Author & Maintainer: Sergio Melas (sergiomelas@gmail.com)  

---

## 1. 📋 Overview & Motivation

Wayplank **V0.5.4** brings major usability enhancements for file management workflows, modern desktop integration, and rendering precision:

1. **Intelligent Drag & Drop Payload Delivery (智能拖拽投递)**:
   - Supports dragging files, folders, URLs, and text from file managers (e.g., Dolphin), web browsers, and desktop onto any Dock application icon.
   - When dropped onto an application icon (e.g., VS Code, Chrome, LibreOffice, GIMP, WeChat), Wayplank resolves target `.desktop` execution parameters and executes `Gio.AppInfo.launch_uris()` with high-fidelity MIME type parsing.
   - Supports dropping items directly onto the Trash icon (`TrashDockItem`) to send them to the system recycle bin via `GLib.File.trash()`.

2. **Spring-Loaded Window Hover Activation (悬停即弹窗)**:
   - When dragging a file and hovering over a running application icon on the Dock for 500ms, the application's active window is automatically brought to the foreground and unminimized via KWin direct bridge.
   - Users can drag a file into an already open document or conversation window without needing manual Alt+Tab or task switching.

3. **Smart Drop Hint Floating Pill Capsule (智能落点胶囊提示)**:
   - While dragging over a Dock item, a high-contrast floating pill capsule is rendered synchronously alongside the tooltip.
   - Dynamically hints the exact action to be taken (e.g. `打开` + `使用 VS Code 打开`, `移至废纸篓`), with clean iconography (`📂`, `🌐`, `🗑️`).

4. **Side Dock Zoom Clipping Fix (修复侧边 Dock 图标放大裁切截断)**:
   - Fixed a rendering defect where application icons on vertical side docks (LEFT or RIGHT) were hard-clipped along the background border when zooming on hover.
   - Refined `DockRenderer.vala` viewport clipping to strictly respect dock orientation: horizontal docks scroll on the X-axis while preserving full vertical zoom space; vertical docks scroll on the Y-axis while preserving full horizontal zoom space.
   - Eliminated redundant clipping operations when dock items fit without overflow scrolling.

5. **Concurrency & Thread Safety**:
   - Resolved asynchronous timer race conditions during drag interactions by synchronizing tooltip and drop hint rendering directly on the main event thread.

---

## 2. 🛠️ Technical Details & Modified Files

- **`lib/Items/ApplicationDockItem.vala` & `lib/System.vala`**:
  - Implemented `deliver_drag_payload()` with robust URI splitting and `Gio.AppInfo.launch_uris()`.
  - Added smart drop action hint generator (`get_drop_action_hint()`).
- **`lib/DragManager.vala`**:
  - Implemented spring-loaded hover timer (500ms) with `start_spring_loaded_timer()` and `cancel_spring_loaded_timer()`.
  - Added external drag payload tracking and MIME filtering.
- **`lib/Widgets/HoverWindow.vala` & `lib/Widgets/DockWindow.vala`**:
  - Added drop pill capsule rendering with customizable badge colors and icons.
  - Reused singleton `HoverWindow` to prevent memory overhead and eliminate async closure race hazards.
- **`lib/DockRenderer.vala`**:
  - Fixed scroll clipping rect for vertical docks (`LEFT`/`RIGHT`), completely eliminating side dock zoom clipping.
- **`include/config.h` & `BuildRpm.sh` & `BuildDeb.sh`**:
  - Version bump to `0.5.4` and updated package release configurations.
