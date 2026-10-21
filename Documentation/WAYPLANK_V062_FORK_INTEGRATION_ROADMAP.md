# 🗺️ WayPlank v0.6.2 Roadmap: Fork Integration & Community Unification

**Document Version:** 1.0  
**Date:** 2026-10-15  
**Maintainer:** Sergio Melas (sergiomelas@gmail.com, GitHub: [@sergiomelas](https://github.com/sergiomelas))  
**Collaborator & Author:** IFtiger-hu (史有虎) (2212363803@qq.com, GitHub: [@IFtiger-hu-hub](https://github.com/IFtiger-hu-hub))  
**Target Milestone:** WayPlank v0.6.2 — "The Community Unification & Distribution Release"  
**Upstream Repository:** [https://github.com/sergiomelas/WayPlank](https://github.com/sergiomelas/WayPlank)  
**Collaborator Fork:** [https://github.com/IFtiger-hu-hub/WayPlank](https://github.com/IFtiger-hu-hub/WayPlank)  

---

## 1. 🤝 Formal Accreditation & Collaboration Authorization

On 2026-10-15, fork author **IFtiger-hu (史有虎)** formally authorized the upstream project maintainer **Sergio Melas** to cherry-pick, adapt, and integrate features, improvements, and bug fixes from the fork (`https://github.com/IFtiger-hu-hub/WayPlank`) directly into upstream `main` for release in **WayPlank v0.6.2**:

> *"You have my full permission and authorization to cherry-pick and adapt any features, improvements, or fixes from my fork (https://github.com/IFtiger-hu-hub/WayPlank) directly into upstream main.*  
> *This includes: Native openSUSE RPM automated packaging support (BuildRpm.sh), launcher deduplication and backend bridge window filtering fixes, dock overflow smooth scrolling and adaptive Light/Dark theme toggle, drag-and-drop file/URL delivery onto dock icons and hover window triggering."*  
> — **IFtiger-hu (史有虎)**, Fork Maintainer

### Formal Attribution Protocol:
1. **Git Commit History Preservation**:
   - Every ported commit from the fork will strictly preserve original author attribution:
     ```bash
     --author="史有虎-openSUSE-Tumbleweed <2212363803@qq.com>"
     ```
2. **README.md Acknowledgments**:
   - A dedicated `## 🤝 Acknowledgments & Contributors` section in `README.md` will prominently recognize IFtiger-hu (史有虎) and link to his GitHub profile and fork.
3. **Changelog & Documentation**:
   - `Changelogs/CHANGELOG_v0.6.2.md` will detail every ported feature with explicit credits and citations.

---

## 2. 🔍 Commit-by-Commit Fork Audit (`fork/main`)

The fork branched from upstream at tag `v0.5.2` (`5729885`) and produced 17 commits up to tag `v0.5.5` (`5693d80`). Here is the granular technical breakdown:

| Fork Commit | Tag / Area | Summary of Changes | Upstream v0.6.1 Status & Overlap | Recommended Action for v0.6.2 |
| :--- | :--- | :--- | :--- | :--- |
| **`ccb79c0`** | `Packaging` | Added native openSUSE / Fedora RPM builder (`BuildRpm.sh`) and spec file template. | 🟢 **Zero overlap**. Upstream only had `.deb` and binary script. Tested and verified working. | ✅ **COMPLETED (Round 1)**: Integrated `BuildRpm.sh` with non-interactive headless CI bypass. |
| **`e1d6a03`** | `v0.5.3` / `Layout` | **Dock Overflow Smooth Scrolling**: Clamps dock background to screen width/height, adds mouse wheel scroll offset, and smooth animated scrolling when items exceed screen bounds. | 🟢 **Zero overlap**. Upstream relied solely on item padding reduction/auto-shrink. | ✅ **COMPLETED (Round 1)**: Integrated overflow scrolling + Preferences Behaviour switch + Tachometer Redline slider. |
| **`9108354`** | `Theming` | Added `lib/Services/SystemTheme.vala` (listening to FreeDesktop portal color-scheme) and `Light/dock.theme`. | 🟡 **Partial overlap**. Upstream v0.6.1 created the dynamic adaptive "Gtk+" engine. | **Phase 2: Integrate Portal Listener**. Wire `SystemTheme.vala` into upstream adaptive theme engine. |
| **`b2b228c`** | `Icons` | System library custom icon chooser dialog (`IconChooserDialog.vala`). | 🔵 **Already Solved in Upstream v0.6.0**. Upstream implemented a full 20,000+ theme icon browser with GIO metadata persistence. | **Review & Compare**: Ensure upstream has all system path fallbacks. |
| **`a19c053`**<br>**`af0293a`**<br>**`b9f8ba7`**<br>**`10809c4`** | `v0.5.4` / `DND` | Drag-and-drop file/URL delivery (`launch_with_uris`), smart drop capsule tooltip, hover window popup activation. | 🟡 **Partial overlap**. Upstream v0.6.1 solved 0-byte MIME fallbacks, folder drops, and bounce feedback. | **Phase 2: Merge Enhancements**. Adopt `launch_with_uris` (remote URLs) & hover window raising. |
| **`81430b3`** | `Themes` | Restored classic Default theme; moved reverse rounded dark theme to standalone `Dark`. | 🟡 **Theme styling**. | **Phase 3: Theme Catalog**. Add `Dark` and `Light` as packaged stock themes. |
| **`5693d80`** | `v0.5.5` / `Core` | **Launcher Deduplication & Item Reuse** in `ItemFactory.vala`; filter `xwaylandvideobridge` in `ApplicationDiscovery.vala` and KWin bridge. | 🟢 **High Value Fix**. Prevents duplicated `.dockitem` generation and ghost bridge windows. | **Phase 1: Port Deduplication & Ghost Filter**. High stability impact. |
| **`81ea31a`** | `Visual` / `Cards` | Multi-window card expansion, reverse fillet skirt rendering, `RecentFilesService.vala`. | ⚠️ **HAL Positioning & Geometry Challenge**. Inline expansion previously risked Mutter/Labwc HAL displacement. | 🔄 **TO MODIFY / GENERALIZE**: Re-architect for universal multi-compositor HAL positioning (KWin, Mutter, Labwc) and geometry preservation. |

---

## 3. 🎯 Detailed Gap Analysis: Upstream v0.6.1 vs Fork

```mermaid
flowchart TD
    classDef integrated fill:#1b5e20,stroke:#81c784,stroke-width:2px,color:#ffffff;
    classDef upstream fill:#1565c0,stroke:#64b5f6,stroke-width:1px,color:#ffffff;
    classDef pending fill:#37474f,stroke:#90a4ae,stroke-width:1px,color:#ffffff;
    classDef modify fill:#e65100,stroke:#ffb74d,stroke-width:2px,color:#ffffff;
    classDef rejected fill:#b71c1c,stroke:#ef5350,stroke-width:2px,color:#ffffff;

    subgraph Upstream_v061["Upstream v0.6.1 Strengths"]
        U1["KWin DRM Multi-Monitor Brightness (kscreen-doctor)"]:::upstream
        U2["Global System Pressure Engine (CPU+RAM+Disk I/O)"]:::upstream
        U3["4 Smart App Drawers (Auto-Creation Onboarding)"]:::upstream
        U4["Cairo-Dock Style Menus with 60 FPS Zoom Elevation"]:::upstream
        U5["Adaptive Dynamic Gtk+ Theme Engine"]:::upstream
        U6["Universal Switch Tooltips & Calibrated Pressure (10px/1px)"]:::upstream
        U7["100% FAT PASS on KDE Plasma 6"]:::upstream
    end

    subgraph Fork_Features["Fork Innovations by IFtiger-hu"]
        F1["✅ [INTEGRATED - Round 1]<br/>Native openSUSE / Fedora RPM Builder (BuildRpm.sh)"]:::integrated
        F2["✅ [INTEGRATED - Round 1]<br/>Dock Overflow Smooth Scrolling (PositionManager + Wheel)"]:::integrated
        F3["✅ [INTEGRATED - Round 1]<br/>Launcher Deduplication & File Reuse (ItemFactory)"]:::integrated
        F4["✅ [INTEGRATED - Round 1]<br/>Ghost Window Filtering (xwaylandvideobridge)"]:::integrated
        F5["✅ [INTEGRATED - Round 2]<br/>DND Remote URL Delivery & Hover Window Activation"]:::integrated
        F6["Recent Files Jump List Service (RecentFilesService)"]:::pending
        F7["🔄 [TO MODIFY / GENERALIZE]<br/>Universal Multi-Window Cards (HAL Positioning)"]:::modify
    end

    subgraph Unified_v062["WayPlank v0.6.2 Unified Milestone"]
        M1["✅ [INTEGRATED - Round 1]<br/>Unified Package Ecosystem: DEB + RPM + Headless CI"]:::integrated
        M2["✅ [INTEGRATED - Round 1]<br/>Rock-Solid Multi-Compositor HAL + Ghost Window Shield"]:::integrated
        M3["✅ [INTEGRATED - Round 1]<br/>Infinite Capacity: Smooth Overflow Scrolling + Redline Slider"]:::integrated
        M4["✅ [INTEGRATED - Round 2]<br/>Rich DND Ecosystem: Files, Folders, URLs & Hover Raise"]:::integrated
        M5["✅ [INTEGRATED - Round 2]<br/>Adaptive Theming: Portal Color-Scheme Sync + Theme Manager"]:::integrated
    end

    Upstream_v061 --> Unified_v062
    F1 --> Unified_v062
    F2 --> Unified_v062
    F3 --> Unified_v062
    F4 --> Unified_v062
    F5 --> Unified_v062
    F6 --> Unified_v062
```

---

## 4. 🚀 Step-by-Step Integration Phases & Version Alignment

To preserve linear versioning, eliminate ambiguity, and provide clean standalone packages for each integration milestone, every Round maps directly to a sequential sub-version (`v0.6.2.x`):

* **v0.6.2.1 (Round 1)**: Native RPM Packaging, Overflow Scrolling, Launcher Deduplication, Ghost Window Shield & Multi-Monitor DDC/CI Sync.
* **v0.6.2.2 (Round 2)**: DND Remote URLs, Hover Window Raising & FreeDesktop Portal Color-Scheme.
* **v0.6.2.3 (Round 3)**: Packaged Stock Themes, Recent Files Jump List & Universal Multi-Window Cards.

---

### Phase 1 (Round 1): Zero-Risk Quick Wins & Core Foundation — 🏁 RELEASE MILESTONE: v0.6.2.1
*Goal: Immediate high-value additions with zero risk to the runtime dock or HAL.*

1. **Native openSUSE / Fedora RPM Packaging (`BuildRpm.sh`)** — ✅ **COMPLETED (v0.6.2.1)**:
   - Port `BuildRpm.sh` from commit `ccb79c0`.
   - Update script to dynamic version extraction (`v0.6.2.1`).
   - Add automated detection of package managers (`zypper`, `dnf`, `apt` for `rpmbuild`).
   - Add `--define "_dbpath %{_topdir}/rpmdb"` to suppress Debian/Ubuntu sqlite database lookup warnings.
   - Add non-interactive headless bypass flags (`WAYPLANK_NO_PROMPT=1`, `CI=1`, `NONINTERACTIVE=1`).
   - Document RPM build steps in `README.md` alongside Debian/Arch instructions.
2. **Launcher Deduplication & Item Reuse (`lib/Factories/ItemFactory.vala`)** — ✅ **COMPLETED (v0.6.2.1)**:
   - Port deduplication logic from commit `5693d80`.
   - In `get_dock_elements_from_dir`: if duplicate URI launcher exists, cleanly prune it.
   - In `create_dock_item`: reuse existing `.dockitem` file matching the URI instead of incrementing `-1.dockitem`, `-2.dockitem`.
   - Attributed to IFtiger-hu (史有虎) downstream fork contribution.
3. **Ghost Window & Screen-Sharing Bridge Shielding (`lib/Services/ApplicationDiscovery.vala` & `lib/Services/KWinBridge.vala`)** — ✅ **COMPLETED (v0.6.2.1)**:
   - Port `is_ignored_app()` to filter out `xwaylandvideobridge` (which generates transparent 1x1 ghost windows during Discord/WebRTC screen sharing on Wayland).
   - Filter `skipTaskbar == true` and `specialWindow == true` in `KWinBridge.vala` and `ApplicationDiscovery.vala`.
   - Attributed to IFtiger-hu (史有虎) downstream fork contribution.

---

### Phase 2 (Round 2): User Experience & Ergonomic Enhancements — 🏁 RELEASE MILESTONE: v0.6.2.2 (100% FAT PASSED)
*Goal: Expand dock navigation, Theme Management, Drag-and-Drop capabilities and portal color sync.*

1. **Dock Overflow Smooth Scrolling (`lib/PositionManager.vala`, `lib/DockRenderer.vala`, `lib/Widgets/DockWindow.vala`)** — ✅ **COMPLETED (v0.6.2.1 / v0.6.2.2)**:
   - Port overflow bounding logic from `e1d6a03`:
     - Calculate `available_content_span` and `max_scroll_offset`.
     - When total icons exceed screen span, clamp background and enable horizontal/vertical scroll offset.
     - Intercept mouse wheel events on dock surface (with volume & brightness docklet bypass) to smoothly shift icons.
     - Smooth interpolation formula: `scroll_offset += (target_scroll_offset - scroll_offset) * 0.35`.
   - Added user setting **`Scroll on Overflow`** toggle switch in **Preferences $\rightarrow$ Behaviour** under Item Management (`scroll-overflow` GSettings key).
   - Added dynamic **Screen Space Capacity Indicator & Auto-Shrink Warning** to Appearance Icon Size slider (Tachometer Redline styling with exact pixel tick marks and explicative tooltips).
   - Preserved Accordion Docklets drawer architecture and prevented docklet scroll event hijacking.
2. **DND Remote URL Delivery & Hover Window Raising (`lib/Services/System.vala`, `lib/DragManager.vala`, `lib/Items/ApplicationDockItem.vala`)** — ✅ **COMPLETED (v0.6.2.2)**:
   - Extended `DragManager.vala` and `System.vala` to handle `http://`, `https://`, `ftp://` web URLs, `.desktop` Type=Link shortcuts (with `URL=` and `URL[$e]=`), and `.url` files.
   - Dropping web URLs on dock background launches system default browser via `AppInfo.launch_default_for_uri()`. Dropping onto browser dock item opens a new tab.
   - Hover window activation: hovering over a running app icon for >500ms during an active drag operation brings that app's window forward via `WindowManager.activate()`, allowing the user to drop directly into the application workspace.
   - Strict pinning precedence: dragging `.desktop` files (including Chrome Web Apps like YouTube/WhatsApp) always pins the item rather than being hijacked by web browser drop handlers.
3. **FreeDesktop Color-Scheme Portal Synchronization (`lib/Services/SystemTheme.vala`, `lib/DrawingService.vala`)** — ✅ **COMPLETED (v0.6.2.2)**:
   - Integrated real-time D-Bus listener on `org.freedesktop.portal.Settings` for `color-scheme` key changes.
   - Linked portal events directly to `Theme.vala` adaptive Gtk+ engine to trigger instantaneous re-rendering on dark/light switch without requiring a dock restart.
4. **Interactive Theme Manager with Native Portal File Chooser (`lib/Services/ThemeManager.vala`, `lib/Widgets/PreferencesWindow.vala`)** — ✅ **COMPLETED (v0.6.2.2)**:
   - Preferences Appearance tab includes interactive `+` (Install) and trash (Delete) buttons.
   - Integrated `Gtk.FileChooserNative` portal dialog for seamless native KDE/GNOME portal integration.
   - Archive scanner extracts `.zip`, `.tar.gz`, `.tar.xz`, `.tar.bz2`, and standalone `.theme` files into `~/.local/share/wayplank/themes/` with multi-theme selection dialogs.
   - Hardened with POSIX `GLib.Shell.quote()` escaping, guaranteed temp directory cleanup, and ellipsized combobox renderer (`Pango.EllipsizeMode.END`).
5. **Strict FreeDesktop MIME Drop Validation (`lib/Items/ApplicationDockItem.vala`)** — ✅ **COMPLETED (v0.6.2.2)**:
   - Enforces `Gio.ContentType` matching against application `.desktop` `MimeType=` entries; incompatible drops are bounced and rejected without falling back to pinning.
6. **Canonical Launcher Deduplication (`lib/Items/DockItemProvider.vala`, `lib/Factories/ItemFactory.vala`)** — ✅ **COMPLETED (v0.6.2.2)**:
   - Canonical matching via `Posix.realpath`, `GLib.File.equal`, and basename comparisons reuses/updates existing items instead of generating `-1.dockitem`, `-2.dockitem`.
7. **KISS Clean Drag-Off Removal & Poof Animation (`lib/Items/DefaultApplicationDockItemProvider.vala`, `lib/DragManager.vala`)** — ✅ **COMPLETED (v0.6.2.2)**:
   - Direct check on `window_count_for_app > 0`: unpinned apps with 0 windows delete immediately and trigger Cairo `PoofWindow` cloud particle animation with zero transient icon ghosting.

---

### Phase 3 (Round 3): Visual Polish & Extended Themes — 🎯 TARGET MILESTONE: v0.6.2.3
*Goal: Enrich theme offerings, Recent Files jump list & generalized Multi-Window Cards.*

1. **Stock Theme Suite (`data/themes/`)**:
   - Integrate `Dark` and `Light` stock themes from `81430b3` and `9108354`.
   - Preserve our adaptive `Gtk+` dynamic engine as the flagship default.
2. **Recent Files Jump List (`lib/Services/RecentFilesService.vala`)**:
   - Port `RecentFilesService` querying `Gtk.RecentManager`.
   - Add "Recent Documents" submenu to compatible application right-click menus.
3. **Multi-Window Window Cards: 🔄 TO MODIFY / GENERALIZE (v0.6.2.3 Round 3)**:
   - **Status**: Re-evaluated from Rejected to To Modify / Generalize.
   - **Architectural Scope**:
     1. *Universal HAL Window Tracking*: Ensure window identification and activation (`WindowControl.queue_command`) operates with identical fidelity across KWin, Mutter, and Labwc.
     2. *HAL Positioning Architecture*: Address the historic HAL positioning challenge on Mutter and Labwc by integrating dynamic bounds recalculation into `PositionManager.vala`, or decoupling cards into an elevated Cairo floating card popup to prevent horizontal dock distortion.
     3. *Configurable Activation*: Provide a user toggle in Preferences -> Behaviour to allow users to choose between classical cyclic window switching and modern multi-window card expansion.

---

## 5. 🛡️ Quality Assurance & FAT Protocol Impact

Every phase will be validated against our standard **Multi-Compositor FAT Matrix** (`FAT/`):

1. **Packaging Validation**:
   - Test `./BuildDeb.sh` on Debian Sid / Ubuntu 24.04.
   - Test `./BuildRpm.sh` on openSUSE Tumbleweed, openSUSE Leap, Fedora 41, and Debian Sid.
   - Verify generated packages install cleanly, register icons, compile schemas, and execute `wayplank --replace`.
2. **Deduplication FAT Point**:
   - Rapidly drag-and-drop the same application multiple times; verify zero duplicate `.dockitem` files are spawned in `~/.config/wayplank/dock1/launchers/`.
3. **Overflow Scrolling FAT Point**:
   - Pin 35+ applications on a 1080p display; verify dock clamps to screen edges, renders cleanly, and mouse wheel scrolls fluidly through the entire launcher sequence without glitching.
4. **Compositor Regression Shield**:
   - Re-run KDE Plasma Session 2 (already 100% PASS), GNOME Session 1, and Labwc Session 3 to guarantee zero regressions.

---

## 6. 🤝 Attribution & Documentation Plan

1. **Git Commit Authorship**:
   - Commits will be imported using `git cherry-pick` or `git commit --author="史有虎-openSUSE-Tumbleweed <2212363803@qq.com>"`.
2. **README.md Acknowledgments**:
   - Add a dedicated section:
     ```markdown
     ## 🤝 Acknowledgments & Contributors
     * **史有虎 (IFtiger-hu)** (@IFtiger-hu-hub): Co-author of native openSUSE/Fedora RPM packaging (`BuildRpm.sh`), dock overflow smooth scrolling architecture, and launcher deduplication engine.
     ```
3. **Changelog Documentation**:
   - All integrated features will be documented in `Changelogs/CHANGELOG_v0.6.2.md` with explicit credits and commit references.

---
*WayPlank Project Documentation • Maintained by Sergio Melas & Contributors*
