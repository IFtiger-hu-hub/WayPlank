# WayPlank V0.6.2 Series Detailed Technical Changelog

Release Series: **V0.6.2 Series (The Community Unification & Distribution Release)**  
Current Milestone: **V0.6.2.1 (Round 1: openSUSE/Fedora RPM, Launcher Deduplication, Overflow Smooth Scrolling, Multi-Monitor DDC/CI Sync & ISA-88 Qualification)**  
Release Date: 2026-10-19  
Authors & Contributors:
- **Sergio Melas** (Maintainer — sergiomelas@gmail.com, GitHub: [@sergiomelas](https://github.com/sergiomelas))
- **史有虎 (IFtiger-hu)** (Collaborator, GitHub: [@IFtiger-hu-hub](https://github.com/IFtiger-hu-hub))

---

## 1. 📋 Overview & Motivation

Wayplank **V0.6.2 series** marks a landmark milestone in the project's evolution: the **unification of upstream WayPlank with the community fork created by IFtiger-hu (史有虎)**. Following formal collaborative agreement, upstream WayPlank integrates the high-value distribution tooling, core item deduplication, and overflow navigation innovations from the fork in progressive, linear validation rounds, expanding WayPlank's reach across the entire Linux ecosystem with full author attribution.

### Core Highlights of v0.6.2.1 (Round 1):
1. **Native openSUSE, Fedora & RHEL Automated RPM Packaging (`BuildRpm.sh`)**: Direct standalone RPM generation supporting openSUSE (Tumbleweed, Leap), Fedora (40, 41), and RHEL/CentOS, featuring automated desktop database integration, GSettings schema compilation, and clean distribution independence alongside our Debian/Ubuntu `.deb` packages.
2. **Launcher Deduplication & Item Reuse Engine (`ItemFactory.vala`)**: Eliminates duplicated `.dockitem` generation (`app-1.dockitem`, `app-2.dockitem`) when re-adding or refreshing launchers, reusing existing valid item definitions and cleanly pruning redundant duplicate URI entries.
3. **Ghost Window & Screen-Sharing Bridge Shielding (`ApplicationDiscovery.vala`)**: Transparently filters background auxiliary windows such as `xwaylandvideobridge` (used by Discord, WebRTC, and OBS for Wayland screen sharing), preventing invisible 1×1 ghost icons from polluting the dock.
4. **Dock Overflow Smooth Scrolling Architecture (`PositionManager.vala`, `DockRenderer.vala`, `DockWindow.vala`)**: Clamps dock background geometry to screen boundaries and enables smooth, interpolated mouse wheel scrolling when pinned and running items exceed available screen span. Includes Preferences toggle ("Scroll on Overflow") and Appearance dynamic capacity redline indicator.
5. **Multi-Monitor DDC/CI Brightness Sync & SP/PV Decoupling (`BrightnessDockItem.vala`)**: Resolves external display backlight synchronization under Mutter and Labwc using a dedicated serialized background worker thread with target coalescing, while architecturally decoupling user Set Point (SP) from background Process Variable (PV) sensor polling to prevent docklet badge bounce.
6. **Consolidated Core Hardening & 100% FAT Qualification**: 279 test points executed across GNOME/Mutter, KDE/KWin, and Labwc with 0 open defects and 12 squashed bugs.

### 🗺️ The V0.6.2 Multi-Round Integration Plan:
* **Round 1 (`v0.6.2.1`) — ✅ Current Release (100% FAT Passed)**:
  - **Distribution & Packaging**: Automated standalone RPM packaging for openSUSE, Fedora and RHEL (`BuildRpm.sh`) with headless CI support.
  - **Core Stability**: ItemFactory launcher deduplication, ghost window & screen-sharing bridge shielding (`xwaylandvideobridge`).
  - **Navigation & Display**: Dock overflow smooth scrolling with tachometer redline capacity indicator, and multi-monitor screen brightness DDC/CI synchronization with architectural SP/PV decoupling.
* **Round 2 (`v0.6.2.2`) — 🎯 In Progress (Ergonomics & DND Enhancements)**:
  - **Remote Web Drag-and-Drop**: Remote web URL delivery (`http://`, `https://`) with automatic browser launching via `DesktopAppInfo.launch_uris()`.
  - **Window Interaction**: Automatic hover window raising during drag operations to simplify dragging files directly into target application workspaces.
  - **System Theme Integration**: Real-time dark/light mode detection via FreeDesktop Settings Portal (`org.freedesktop.portal.Settings`).
* **Round 3 (`v0.6.2.3`) — 🎯 Planned (Visual Polish & Extended Productivity)**:
  - **Extended Theme Suite**: Packaged classic stock themes (Dark and Light variants).
  - **Productivity**: Recent Files jump list accessible directly from application context menus (`RecentFilesService`).
  - **Window Cards**: Universal, generalized multi-window Cairo preview cards across all Wayland compositors.

---

## 2. 📦 Native openSUSE / Fedora / RHEL RPM Packaging (`BuildRpm.sh`)

### Context & Need
While WayPlank provided comprehensive Debian/Ubuntu packaging (`BuildDeb.sh`), openSUSE and Fedora users previously had to build manually from source or convert Debian packages.

### Architectural Solution
WayPlank v0.6.2.1 (Round 1) integrates `BuildRpm.sh`, authored by **史有虎 (IFtiger-hu)** and refined for upstream:
- **Standalone Isolated Workspace**: Prepares source payloads under `build_rpm_workspace/` with automated spec file synthesis.
- **Cross-Distribution Portability**: Automatically handles:
  - openSUSE: `zypper install rpm-build`
  - Fedora: `dnf install rpm-build`
  - Debian/Ubuntu: `apt install rpm` (with `--define "_dbpath %{_topdir}/rpmdb"` to prevent non-root sqlite database collisions)
- **Standardized RPM File System Hierarchy**:
  - Binary in `/usr/bin/wayplank` with symlink `/usr/bin/plank`
  - Desktop integration in `/usr/share/applications/`
  - Themes in `/usr/share/wayplank/themes/`
  - Icons across all standard hicolor dimensions (16×16 to scalable)
  - Post-install scriptlets executing `glib-compile-schemas`, `gtk-update-icon-cache`, and `update-desktop-database`.
- **Target Output**: Generates clean, signed-ready packages: `build/wayplank-0.6.2.1-1.x86_64.rpm`.

---

## 3. 🧹 Launcher Deduplication & Item Reuse (`lib/Factories/ItemFactory.vala`)

### The Problem
When users repeatedly launched, pinned, or rearranged items with identical URIs or application IDs, previous versions incremented numeric suffixes (`firefox-1.dockitem`, `firefox-2.dockitem`) or left duplicate definitions in `~/.config/wayplank/dock1/launchers/`.

### The Solution
1. **URI Deduplication on Load**: In `get_dock_elements_from_dir()`, WayPlank now checks `find_item_for_uri(result, item.Launcher)`. If a dock item with an identical launcher URI already exists in the active dock set, the redundant duplicate is safely deleted from disk and ignored.
2. **Deterministic Item Reuse**: In `create_dock_item()`, before incrementing numeric filenames, WayPlank queries existing items for `get_launcher_from_dockitem(dockitem_file)`. If an existing dock item file already targets the desired URI, WayPlank reuses it directly, eliminating file churn and maintaining clean launcher directories.

---

## 4. 🛡️ Ghost Window & Screen-Sharing Bridge Filtering (`lib/Services/ApplicationDiscovery.vala`)

### The Problem
Under Wayland, tools like `xwaylandvideobridge` (standard KDE/GNOME tool enabling legacy X11 applications like Discord, Zoom, or Slack to capture Wayland screens) create hidden 1×1 pixel toplevel surfaces. WayPlank previously attempted to match these auxiliary surfaces to `.desktop` entries, spawning empty or unwanted bridge icons on the running section of the dock.

### The Solution
Added `ApplicationDiscovery.is_ignored_app()`:
```vala
public static bool is_ignored_app (string? app_id)
{
    if (app_id == null || app_id == "")
        return false;
    var lower = app_id.down ();
    return lower.contains ("xwaylandvideobridge")
        || lower == "wayplank";
}
```
In `best_desktop_file_for_window()`, any window matching ignored application IDs, resource classes, resource names, or desktop file names is discarded immediately, preserving a clean running application bar.

---

## 5. 🌊 Dock Overflow Smooth Scrolling (`lib/PositionManager.vala`, `lib/DockRenderer.vala`, `lib/Widgets/DockWindow.vala`)

### The Problem
On smaller displays (e.g. 1366×768 laptops) or when users pinned a very large number of applications, the dock previously exceeded the physical monitor width or shrank icon sizes aggressively.

### The Solution
Integrated the smooth overflow scrolling architecture authored by **史有虎 (IFtiger-hu)**:
1. **Boundary Clamping**:
   - `width = int.min(monitor_geo.width, width);`
   - `background_width = int.min(monitor_geo.width, background_width);`
2. **Scroll Offset Calculation**:
   - `available_content_span = width - 2.0 * items_offset;`
   - When `current_items_span > available_content_span`, `max_scroll_offset` is dynamically computed.
3. **Smooth Interpolated Movement**:
   - Scroll events are interpolated smoothly: `scroll_offset += (target_scroll_offset - scroll_offset) * 0.35`.
4. **Mouse Wheel Interception**:
   - Mouse wheel events over the dock surface shift the view by 80px (or smooth delta fractions), while preserving volume docklet adjustment when hovering over the volume icon.

---

## 6. 🤝 Community Attribution & Collaboration Log

This milestone exemplifies collaborative open-source synergy:
- **Collaboration Initiated**: 2026-10-15 via direct maintainer exchange.
- **Authorization**: Full mutual consent to cherry-pick, adapt, and integrate fork features under Option 2.
- **Git Authorship**: Preserved on all imported code chunks (`史有虎 (IFtiger-hu)`).
- **Roadmap & Strategy**: Documented in `Documentation/WAYPLANK_V062_FORK_INTEGRATION_ROADMAP.md`.

---

## 7. 🧪 Testing & Validation Matrix (FAT)

- **Debian SID (amd64)**: `./BuildDeb.sh` builds cleanly -> `build/wayplank_0.6.2.1_amd64.deb`.
- **openSUSE / Fedora / RHEL (x86_64)**: `./BuildRpm.sh` builds cleanly with custom local `_dbpath` -> `build/wayplank-0.6.2.1-1.x86_64.rpm`.
- **KDE Plasma 6 (KWin Backend)**: FINISHED (100% Passed) | 90 [ok] | 3 [ko->ok] | 0 [NA] | 0 Open.
- **GNOME Shell (Mutter Backend)**: FINISHED (100% Passed) | 86 [ok] | 7 [ko->ok] | 0 [NA] | 0 Open.
- **Labwc (wlroots Backend)**: FINISHED (100% Passed) | 89 [ok] | 2 [ko->ok] | 2 [NA] | 0 Open.
- **Total Qualification Scoreboard**: 279 Tests Executed | 265 [ok] | 12 Bugs Squashed [ko->ok] | 0 Open Defects (100% Compliant).

