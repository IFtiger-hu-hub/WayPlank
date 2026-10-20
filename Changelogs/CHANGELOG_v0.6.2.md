# WayPlank V0.6.2 Series Detailed Technical Changelog

Release Series: **V0.6.2 Series (The Community Unification & Distribution Release)**  
Current Milestone: **V0.6.2.2 (Round 2: Ergonomics, DND Remote URLs, Hover Window Raising & Portal Color-Scheme) - In Development**  
Release Date: 2026-10-20  
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
6. **Weather Forecast Vector Fallback & Direct Yr.no Navigation (`DrawingService.vala`, `WeatherWindow.vala`, `WeatherDockItem.vala`)**: Eliminates broken icon placeholders by guaranteeing 100% vector fallback to bundled SVG assets. Adds high/low temperature ranges (▲/▼), localized weekday formatting, condition details (humidity and wind speed), and direct headless Yr.no location resolution for one-click browser navigation.
7. **Volume Docklet Overamplification Guard (`VolumeDockItem.vala`)**: Prevents speaker damage from unlimited relative volume runaway. Replaces unbounded relative increments (`+5%`) with absolute capped volume commands (`wpctl set-volume -l 1.5` and `pactl set-sink-volume`), strictly enforcing the 150% maximum limit and blocking scroll wheel overflow.
8. **Application Identity & Wrapper Matching Engine Hardening (`ApplicationIdentity.vala`, `ApplicationDiscovery.vala`)**:
   - **Recursive Command Unwrapping**: Recursively peels wrapper commands (`sh -c`, `bash -c`, `env VAR=val`, `firejail`, `flatpak-spawn`, `flatpak run`, `pkexec`, `sudo`, `systemd-inhibit`) to reliably identify target application binaries (e.g. MATLAB under Firejail, Scilab under Mesa GL overrides).
   - **Dynamic Drawer Folder Discovery**: Automatically indexes custom drawer folder directories referenced by dockitems (`~/.config/wayplank/dock*/launchers/`), ensuring applications pinned inside category drawers (Engineering, Games, Internet) are discovered and tracked.
   - **Hardened Script Wrapper Inspection**: Accurately inspects user shell launcher scripts (e.g. `winchrome-syensqo.sh`) with strict shell-shebang and <4KB size bounds, extracting instance-specific options (`--profile-directory=...`, `--class=...`).
   - **Tiered Scoring & Specialized Launcher Isolation**: Prioritizes specialized instances with score 110 when arguments match, while strictly zeroing scores (`return 0`) on generic windows. Eliminates cross-app false positives (e.g. Scilab vs Quake 2) and protects standard browser windows from profile hijacking.
9. **Consolidated Core Hardening & 100% FAT Qualification**: 279 test points executed across GNOME/Mutter, KDE/KWin, and Labwc with 0 open defects and 18 squashed bugs.

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

## 6. 🛡️ Application Identity & Wrapper Engine Hardening

### Motivation & Root Cause Analysis
Complex application launchers in Linux frequently wrap native binaries in shell scripts or sandbox layers:
1. **Sandboxes & Environment Overrides**:
   - MATLAB: `Exec=sh -c "TMPDIR=$HOME/.cache/matlab-tmp firejail /usr/local/MATLAB/R2024a/bin/matlab -desktop"`
   - Scilab: `Exec=env MESA_GL_VERSION_OVERRIDE=3.0 /usr/local/SCILAB/scilab-2025.1.0/bin/scilab %f`
2. **User Launcher Scripts with Specific Profiles**:
   - Syensqo Chrome: `winchrome-syensqo.sh` running `/opt/google/chrome/google-chrome ... --profile-directory="Profile 14"`
3. **Category Drawer Folders**:
   - Custom `.desktop` files stored exclusively inside dock drawer folders (e.g. `~/.config/wayplank/dock1/launchers/Enginnering` or `Games`) were previously not indexed by standard XDG search directories.

### Architecture & Implementation
- **Recursive Command Unwrapping (`unwrap_command_string`)**:
  Recursively strips command wrappers (`sh -c`, `bash -c`, `env VAR=val`, `firejail`, `flatpak-spawn`, `flatpak run`, `pkexec`, `sudo`, `systemd-inhibit`) to locate the genuine target executable. Automatically registers binary aliases (e.g. `scilab` ↔ `scilab-bin`, `google-chrome` ↔ `chrome`).
- **Dynamic Category Drawer Indexing (`application_folders`)**:
  Inspects all `*.dockitem` entries in `~/.config/wayplank/dock*/launchers/` for directory URIs, adding drawer folder paths directly to the desktop search paths.
- **Bounded Script Inspection (`inspect_script_file`)**:
  Restricts script file parsing strictly to `.sh` user launcher scripts (<4KB bounds, shell shebang enforcement). Prevents reading system scripts or Python wrappers (e.g. `gdp-launcher`).
- **Specialized Launcher Isolation & Prioritization (`match_score`)**:
  When a launcher targets a specific profile (`--profile-directory=...`), it receives score **110** when the window matches. If the window does not match the specialized arguments, the launcher score is strictly zeroed (`return 0`), ensuring specialized launchers never steal generic application windows.

---

## 7. 🤝 Community Attribution & Collaboration Log

This milestone exemplifies collaborative open-source synergy:
- **Collaboration Initiated**: 2026-10-15 via direct maintainer exchange.
- **Authorization**: Full mutual consent to cherry-pick, adapt, and integrate fork features under Option 2.
- **Git Authorship**: Preserved on all imported code chunks (`史有虎 (IFtiger-hu)`).
- **Roadmap & Strategy**: Documented in `Documentation/WAYPLANK_V062_FORK_INTEGRATION_ROADMAP.md`.

---

## 8. 🧪 Testing & Validation Matrix (FAT v0.6.2.1 Final)

- **Debian SID (amd64)**: `./BuildDeb.sh` builds cleanly -> `build/wayplank_0.6.2.1_amd64.deb`.
- **openSUSE / Fedora / RHEL (x86_64)**: `./BuildRpm.sh` builds cleanly with custom local `_dbpath` -> `build/wayplank-0.6.2.1-1.x86_64.rpm`.
- **KDE Plasma 6 (KWin Backend)**: FINISHED (100% Passed) | 89 [ok] | 5 [ko->ok] | 0 [NA] | 0 Open.
- **GNOME Shell (Mutter Backend)**: FINISHED (100% Passed) | 86 [ok] | 8 [ko->ok] | 0 [NA] | 0 Open.
- **Labwc (wlroots Backend)**: FINISHED (100% Passed) | 89 [ok] | 3 [ko->ok] | 2 [NA] | 0 Open.
- **Total Qualification Scoreboard**: 282 Tests Executed | 264 [ok] | 16 Bugs Squashed [ko->ok] | 0 Open Defects (100% Compliant).

---

## 9. 🚧 WayPlank V0.6.2.2 (Round 2: Ergonomics, DND Remote URLs & Portal Sync) — In Development

- **DND Remote Web URL Delivery (`http://`, `https://`)**:
  - Extends drag-and-drop to handle web URLs dragged from browsers, bookmarks, or web applications.
  - Automatically dispatches URLs to running or target browsers via `DesktopAppInfo.launch_uris()`.
- **Hover Window Activation During Drag**:
  - Pausing hover over a running application icon for >500ms during an active drag operation brings that application's window to the foreground.
  - Enables direct drop into the target application workspace without manual task switching.
- **FreeDesktop Settings Portal Color-Scheme Synchronization**:
  - Listens to `org.freedesktop.portal.Settings` for `color-scheme` changes (Dark/Light).
  - Dynamically triggers dock theme re-rendering when the system switches color modes without requiring dock restart.

