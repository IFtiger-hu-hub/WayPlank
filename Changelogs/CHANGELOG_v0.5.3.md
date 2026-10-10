# Wayplank V0.5.3 Detailed Technical Changelog

Release Milestone: **V0.5.3** (Dock Screen Width Clamping, Horizontal Viewport Overflow Scrolling & Multi-Window Stability)  
Release Date: 2026-10-10  
Author & Maintainer: Sergio Melas (sergiomelas@gmail.com)  

---

## 1. 📋 Overview & Motivation

When many applications are launched or multiple window cards are expanded (e.g. Dolphin file manager instances), previous versions allowed dock items to expand horizontally without boundary constraints, pushing the dock and its elements off-screen edges.

Wayplank **V0.5.3** resolves this fundamental design limitation:
1. **Screen Width Boundary Clamping**: The maximum dock width is strictly clamped to the current monitor's physical width (`monitor_geo.width`), preventing the dock from ever escaping screen boundaries.
2. **Horizontal Viewport Overflow Scrolling**: When the total span of dock items exceeds available screen width, items become smoothly scrollable within the dock container.
3. **Smooth Damping & Animation**: Internal scroll position uses interpolated damping physics (`scroll_offset` + `target_scroll_offset`) driven by WayPlank's high-efficiency render loop.
4. **Cairo Hardware-Accelerated Viewport Clipping**: Both items and shadows are clipped to the dock background rect, completely eliminating artifact leaks outside the dock.
5. **Dynamic Edge Indicators**: Subtle translucent gradient masks and directional chevrons (`<` and `>`) automatically illuminate at dock edges when hidden items are present.
6. **Multi-Input Gestures**: Supports mouse wheel scrolling (Up/Down and Left/Right) as well as touchpad smooth kinetic two-finger scrolling.
7. **Dock Background Alignment Fix**: Resolved background rect vertical positioning regression when overflow is active.

---

## 2. 🛠️ Technical Details & Modified Files

- **`lib/PositionManager.vala`**:
  - Clamped `width`, `background_width`, and `VisibleDockWidth` to `monitor_geo.width`.
  - Added `scroll_offset`, `target_scroll_offset`, `max_scroll_offset`, `is_scrolling()`, `scroll_by()`, and `ensure_item_visible()`.
  - Preserved `static_dock_region.y` in `update_background_region()` to guarantee the pill background encloses dock icons at the screen bottom.
- **`lib/DockRenderer.vala`**:
  - Added horizontal clipping on `item_cr` and `shadow_cr`.
  - Added `draw_scroll_edge_indicators()` rendering directional arrows and gradient masks.
  - Linked `is_scrolling()` to render loop frame requests.
- **`lib/Widgets/DockWindow.vala`**:
  - Implemented mouse wheel and touchpad smooth gesture handling in `scroll_event()`.
- **`lib/Items/ApplicationDockItem.vala`**:
  - Automatically scrolls newly expanded window cards into the visible viewport via `ensure_item_visible()`.
- **`BuildRpm.sh` & `BuildDeb.sh`**:
  - Version bump to `0.5.3` with automated single-command RPM and DEB packaging support.
