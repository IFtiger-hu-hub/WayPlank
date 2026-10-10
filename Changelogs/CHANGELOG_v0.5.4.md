# Wayplank V0.5.4 Detailed Technical Changelog

Release Milestone: **V0.5.4** (Intelligent Drag & Drop Payload Delivery, Spring-Loaded Window Activation, Smart Drop Capsule & Side Dock Viewport Clipping Fix)  
Release Date: 2026-10-11  
Author & Maintainer: 史有虎 (2212363803@qq.com) / Sergio Melas  
Repository: [IFtiger-hu-hub/WayPlank](https://github.com/IFtiger-hu-hub/WayPlank)

---

## 1. 📋 Overview & Motivation

Wayplank **V0.5.4** delivers a major upgrade for desktop productivity, cross-application file dispatching, and high-fidelity rendering precision across Linux Wayland desktop environments (KDE Plasma/KWin, GNOME/Mutter, Labwc/wlroots).

In modern desktop workflows, dragging files directly from file managers (Dolphin, Nautilus), web browsers, or the desktop onto Dock icons is an essential interaction paradigm. Previous versions treated Dock icons as pure click-launchers, lacking the ability to accept external file payloads or automatically raise background windows during a drag. Furthermore, vertical side docks suffered from an orientation-dependent viewport clipping defect that truncated zoomed icons.

Wayplank **V0.5.4** systematically resolves these limitations through five core innovations:

1. **Intelligent Drag & Drop Payload Delivery (智能拖拽投递与自动启动)**:
   - Supports dragging files, directories, URLs, and text from external applications onto any Dock application icon.
   - Automatically parses desktop execution actions, resolving target `.desktop` parameters and executing asynchronous `Gio.AppInfo.launch_uris()` with MIME-aware arguments.
   - Integrated native system trash recycling: dragging files or folders onto the Trash icon (`TrashDockItem`) immediately triggers native `GLib.File.trash()`.

2. **Spring-Loaded Window Activation (悬停即弹窗)**:
   - When hovering a dragged payload over a running application icon for 500ms, Wayplank automatically unminimizes and raises the application's active window to the foreground via KWin / Wayland foreign toplevel bridge.
   - Eliminates awkward `Alt+Tab` multitasking while holding down the mouse button.

3. **Smart Drop Hint Floating Pill Capsule (智能落点悬浮胶囊提示)**:
   - Dynamically renders a high-contrast floating pill capsule directly adjacent to the hovered icon during drag.
   - Provides clear, actionable operation context (e.g. `📂 打开 | 使用 VS Code 打开`, `移至废纸篓`), complete with iconography (`📂`, `🌐`, `🗑️`).

4. **Side Dock Viewport Clipping & Orientation Fix (修复侧边 Dock 图标放大截断)**:
   - Fixed a rendering defect introduced by viewport scrolling where vertical docks (LEFT or RIGHT) hard-clipped zooming icons along the narrow background border.
   - Re-architected viewport clipping in `DockRenderer.vala` to strictly adhere to dock orientation: horizontal docks scroll along X while granting full vertical zoom space; vertical docks scroll along Y while granting full horizontal zoom space.
   - Completely bypasses clipping calculations when dock items fit without viewport overflow.

5. **Real-World Desktop Visual Showcase (实机全形态截图归档)**:
   - Added 6 authentic, pixel-perfect real desktop screenshots to `screenshots/` and `README.md`, showcasing light frosted glass, dark matte, side vertical dock, inline window cards, and KWin Present Windows integration.

---

## 2. 🛠️ Technical Details & Architecture Breakdown

### 1. Payload Dispatching Pipeline (`lib/Items/ApplicationDockItem.vala`, `lib/System.vala`, `lib/Items/TrashDockItem.vala`)

- **URI Normalization & Argument Parsing**:
  - Implemented `deliver_drag_payload(string text, Gdk.DragContext context)` in `ApplicationDockItem.vala`.
  - Automatically filters `file://` URIs and web URLs (`http://`, `https://`), converting them into clean `GLib.File` object arrays.
- **Asynchronous App Launch**:
  - Uses `Gio.AppInfo.launch_uris()` bound to the application's real `.desktop` identity, ensuring complete compatibility with flatpak, native packages, and sandboxed apps.
- **Trash Recycling Dispatcher**:
  - In `TrashDockItem.vala`, implemented `deliver_drag_payload()` to parse dragged local files and invoke `GLib.File.trash_async()` on the main event loop, accompanied by icon state updates.

### 2. Spring-Loaded Window Timer (`lib/DragManager.vala`)

- **Event-Driven Timer**:
  - Introduced `spring_hover_timer_id` (500ms timeout) in `DragManager.vala`.
  - Timer is primed when `ExternalDragActive` is true and a valid `HoveredItem` is entered.
  - Automatically cancels via `cancel_spring_loaded_timer()` upon `drag_leave`, item switch, or successful drop, guaranteeing zero leaked timer callbacks.
- **Immediate KWin Unminimize & Raise**:
  - When the 500ms threshold expires, dispatches direct window activation (`WindowControl.activate()`) to restore and raise the topmost window belonging to the hovered application.

### 3. Synchronous Thread-Safe Capsule Pill (`lib/Widgets/HoverWindow.vala`, `lib/Widgets/DockWindow.vala`)

- **Elimination of Async Timer Race Hazards**:
  - Converted hover tooltip and capsule hint dispatching in `DockWindow.vala` from asynchronous `Gdk.threads_add_timeout` closures to synchronous main-thread execution.
  - Completely eliminates null-pointer `SIGSEGV` edge cases caused by rapid pointer movement across dock elements during drag operations.
- **Single Window Resource Reuse**:
  - The drop hint capsule is rendered directly inside the existing `HoverWindow` singleton, avoiding creation of secondary GTK window surfaces, extra input regions, or redundant layer-shell allocations.

### 4. Dual-Axis Viewport Clipping Engine (`lib/DockRenderer.vala`)

- **Axis-Aware Clipping**:
  - Prior logic hardcoded `item_cr.rectangle (background_rect.x, 0, background_rect.width, win_rect.height)`. On vertical docks, `background_rect.width` is only ~50px, violently cutting off icons expanding into the screen interior.
  - Refactored clipping to evaluate dock orientation:
    ```vala
    bool need_scroll_clip = (position_manager.max_scroll_offset > 0.0);
    if (need_scroll_clip) {
        item_cr.save ();
        shadow_cr.save ();
        if (position_manager.is_horizontal_dock ()) {
            item_cr.rectangle (background_rect.x, 0, background_rect.width, win_rect.height);
            shadow_cr.rectangle (background_rect.x, 0, background_rect.width, win_rect.height);
        } else {
            item_cr.rectangle (0, background_rect.y, win_rect.width, background_rect.height);
            shadow_cr.rectangle (0, background_rect.y, win_rect.width, background_rect.height);
        }
        item_cr.clip ();
        shadow_cr.clip ();
    }
    ```
- **Zero-Cost Normal Path**:
  - When `max_scroll_offset <= 0.0` (all items fit on dock), clipping is completely skipped, eliminating 2 Cairo `clip()` operations and `save()`/`restore()` stack frames per render cycle.

---

## 3. 📊 Performance & Memory Benchmark

Detailed profiling conducted on openSUSE Tumbleweed Linux x86_64 under active KDE Plasma 6 Wayland session:

| Profile Metric                    | Measured Value | Analysis & Verdict                                                     |
| :-------------------------------- | :------------- | :--------------------------------------------------------------------- |
| **Idle CPU Usage**                | **0.00%**      | Zero background polling or busy loops.                                 |
| **Private Dirty Heap Memory**     | **~44.7 MB**   | Dedicated WayPlank process heap and icon caches.                       |
| **Resident Set Size (RSS)**       | **~85.5 MB**   | Includes all shared GTK3, Cairo, Wayland, and Mesa graphics libraries. |
| **Proportional Set Size (PSS)**   | **~56.1 MB**   | True normalized system memory footprint.                               |
| **Native Binary Footprint Delta** | **+456 Bytes** | Binary size increased by less than half a kilobyte (4.45 MB total).    |

---

## 4. 📦 Packaging & Build Distribution

- **Standalone RPM Package**: `build/wayplank-0.5.4-1.x86_64.rpm` (1.29 MB)
  - Single-command installation:
    ```bash
    sudo zypper install --allow-unsigned-rpm build/wayplank-0.5.4-1.x86_64.rpm
    # or on Fedora / RHEL:
    sudo rpm -Uvh build/wayplank-0.5.4-1.x86_64.rpm
    ```
- **Standalone Binary**: `build/wayplank` (4.45 MB)
- **Version Tracking**:
  - `include/config.h`: Bumper to `0.5.4`
  - `BuildRpm.sh`: Bumper to `0.5.4`
  - `BuildDeb.sh`: Bumper to `0.5.4`
  - `README.md`: Updated release badges, installation instructions, and real screenshot showcase gallery.
