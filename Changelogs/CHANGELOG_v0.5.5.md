# Wayplank V0.5.5 Detailed Technical Changelog

Release Milestone: **V0.5.5** (Launcher Deduplication, Atomic Item Reuse, Ghost Window Filtering & Reboot Stability)  
Release Date: 2026-10-12  
Author & Maintainer: 史有虎 (2212363803@qq.com) / Sergio Melas  
Repository: [IFtiger-hu-hub/WayPlank](https://github.com/IFtiger-hu-hub/WayPlank)

---

## 1. 📋 Overview & Motivation

Wayplank **V0.5.5** addresses critical Dock item persistence, reboot restoration integrity, and ghost window handling across Linux Wayland desktop environments (KDE Plasma/KWin, GNOME/Mutter, Labwc/wlroots).

In previous releases, users encountered docking order disarray and duplicate application entries upon system reboot or Dock restarts. Specifically:
1. **Deduplication Logic Failure**: In `ItemFactory.vala`, the duplicate detection algorithm executed against an unpopulated list during directory enumeration, rendering duplicate checks completely ineffective.
2. **Proliferation of Suffixed Launchers**: When re-pinning or dragging running applications, `make_dock_item()` blindly incremented numeric suffixes (`name-1.dockitem`, `name-2.dockitem`) even when an identical launcher URI was already present on disk.
3. **Background Daemon Windows (`xwaylandvideobridge`)**: Background utilities like KDE Plasma's `xwaylandvideobridge` were improperly captured as regular client windows, creating unexpected `TransientDockItem` instances and triggering dynamic dual separators on the Dock.

Wayplank **V0.5.5** systematically eliminates these issues, guaranteeing reliable icon positioning and clean session reboots.

---

## 2. 🛠️ Technical Details & Architecture Breakdown

### 1. Robust Launcher Deduplication Pipeline (`lib/Factories/ItemFactory.vala`)

- **Result-Aware Deduplication in `load_elements()`**:
  - Re-architected item ingestion to perform deduplication when ordering elements into `result`.
  - Priority is given to the first instance specified by the user's persisted `ordering` configuration.
  - Any subsequent `.dockitem` files sharing the same `item.Launcher` URI are identified (`dupe != null`), deleted from the disk via `item.delete()`, and excluded from the active Dock.
  - Non-ordered files remaining in `elements.values` undergo the same validation, ensuring zero redundant launcher instances persist across sessions.

### 2. Atomic Launcher File Reuse (`lib/Factories/ItemFactory.vala`)

- **Pre-Check Existing Launcher URIs in `make_dock_item()`**:
  - Before allocating a new `-1`, `-2`, `-3` numeric filename suffix, `make_dock_item()` now inspects existing `.dockitem` files in the target folder via `get_launcher_from_dockitem()`.
  - If a file already maps to the requested URI, the existing file is returned immediately without creating disk clutter.

### 3. KWin Window Filtering (`lib/Services/KWinBridge.vala`)

- **Taskbar & Special Window Exclusion**:
  - Enhanced ECMAScript window enumeration in `sendWindowState()` and `connectWindow()` to respect `client.skipTaskbar === true` and `client.specialWindow === true`.
  - Directly blacklists `xwaylandvideobridge` and `wayplank` from being tracked as regular client windows, preventing ghost transient entries and unwarranted dynamic separator expansion.

### 4. Global Ignored Application Filter (`lib/Services/ApplicationDiscovery.vala`)

- **Centralized App Filtering**:
  - Introduced `ApplicationDiscovery.is_ignored_app(string? app_id)` to filter background bridges across all compositors.
  - Checked upfront in `best_desktop_file_for_window()`, ensuring background bridges are never assigned desktop identities or promoted to the Dock.

---

## 3. 📦 Packaging & Build Distribution

- **Standalone RPM Package**: `build/wayplank-0.5.5-1.x86_64.rpm`
- **Standalone Binary**: `build/wayplank`
- **Version Tracking**:
  - `include/config.h`: Bumped to `0.5.5`
  - `BuildRpm.sh`: Bumped to `0.5.5`
  - `BuildDeb.sh`: Bumped to `0.5.5`
  - `README.md`: Updated release badges and changelog history
