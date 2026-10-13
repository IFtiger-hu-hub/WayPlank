# WayPlank User Guide & Reference Manual

Welcome to **WayPlank**, the fast, lightweight, and modern dock designed natively for the Wayland desktop environment (GNOME / Mutter and beyond).

This manual provides an in-depth reference for all features, configuration options, gestures, and advanced setups—such as folder-based application menus, docklets, accordion collapsing, and multi-monitor layouts.

---

## Table of Contents
1. [Introduction](#1-introduction)
2. [Quick Start & Interface Layout](#2-quick-start--interface-layout)
3. [Folder Launchers (App Drawer Menus)](#3-folder-launchers-app-drawer-menus)
   - [How Folder Launchers Work](#how-folder-launchers-work)
   - [Default First-Run Folders](#default-first-run-folders)
   - [Creating Custom Folders](#creating-custom-folders)
   - [Adding and Managing Applications](#adding-and-managing-applications)
   - [Customizing Icons (Launchers, Folders & Docklets)](#customizing-icons-launchers-folders--docklets)
4. [Built-in Docklets & Accordion Mode](#4-built-in-docklets--accordion-mode)
   - [Complete List of 15 Docklets](#complete-list-of-15-docklets)
   - [Accordion Mode (Space-Saving Collapsible Docklets)](#accordion-mode-space-saving-collapsible-docklets)
   - [Configuring the Weather Docklet](#configuring-the-weather-docklet)
5. [Categorization & Dynamic Separators](#5-categorization--dynamic-separators)
   - [Categorized Layout Order](#categorized-layout-order)
   - [Permanent Trash Anchoring](#permanent-trash-anchoring)
   - [Dynamic Separators](#dynamic-separators)
6. [Mouse Gestures & Shortcuts](#6-mouse-gestures--shortcuts)
   - [Click Actions](#click-actions)
   - [Scroll Gestures](#scroll-gestures)
   - [Drag & Drop Interactions](#drag--drop-interactions)
   - [Quick Settings Access & In-App Help](#quick-settings-access--in-app-help)
7. [Multi-Monitor & Wayland Desktop Integration](#7-multi-monitor--wayland-desktop-integration)
   - [Monitor Selection & Alignment](#monitor-selection--alignment)
   - [Intelligent Hide & Edge Pressure](#intelligent-hide--edge-pressure)
   - [GNOME Shell Mutter Extension Architecture](#gnome-shell-mutter-extension-architecture)
8. [Themes & Visual Customization](#8-themes--visual-customization)
   - [Built-in Themes](#built-in-themes)
   - [Installing Custom Themes](#installing-custom-themes)
   - [Dock Size & Zoom Level](#dock-size--zoom-level)
9. [Command Line Usage & Configuration Files](#9-command-line-usage--configuration-files)
   - [CLI Commands](#cli-commands)
   - [Configuration File Paths](#configuration-file-paths)
   - [GSettings Database Keys](#gsettings-database-keys)
10. [Troubleshooting & FAQ](#10-troubleshooting--faq)

---

## 1. Introduction

WayPlank is a native port and evolution of the classic Plank dock, rebuilt to thrive in modern Wayland display servers without X11 or XWayland workarounds.

### Key Highlights
- **Native Wayland Performance:** Powered by a direct asynchronous Mutter backend extension with zero boot latency (sub-second startup).
- **Categorized Dock Layout:** Automatic visual grouping of Folders, Docklets, Pinned Launchers, Running Windows, and the Trash can.
- **Folder Launchers:** Turn any directory into a Cairo-Dock style popup application menu.
- **Accordion Docklets:** Keep system widgets accessible without cluttering your desktop space.
- **Fluid Animations:** Smooth zoom, bounce on launch, window attention indicators, and smoke poof animations when unpinning.

---

## 2. Quick Start & Interface Layout

When WayPlank starts with default settings, the dock is arranged into clean, logical visual sections separated by dynamic dividers:

```
[ Folders ]   |   [ Docklets ]   |   [ Pinned Apps ]   |   [ Open Apps ]   |   [ Trash ]
 📁 Internet        🎛️ Accordion       🌐 Web Browser       📝 Kate             🗑️ Trash
 💼 Office          (Preferences,      📁 File Manager      ...
 🎬 Media            Desktop,          💻 Terminal
 🎮 Games            Volume...)        ⚙️ Editor
```

- **Folders (Left):** Categorized application menus for fast access to your software library.
- **Docklets (Center-Left):** Interactive system widgets collapsed into an expandable accordion.
- **Pinned Applications (Center):** Direct single-click access to your essential daily tools.
- **Running Applications (Center-Right):** Temporary icons for active, unpinned windows.
- **Trash (Right):** Anchored permanently at the end of the dock for quick file disposal and ejection.

---

## 3. Folder Launchers (App Drawer Menus)

Folder Launchers provide a clean way to organize dozens of applications into compact menus directly on your dock.

### How Folder Launchers Work
When a dock item points to a directory (e.g., `Launcher=file:///path/to/directory`), WayPlank treats it as an application drawer. Clicking on it opens a menu displaying all `.desktop` applications found inside that folder, complete with their native icons and localized names.

### Default First-Run Folders
When WayPlank starts for the first time without an existing configuration, it automatically creates and populates four core folders under `~/.config/wayplank/folders/`:

1. **`Internet`**: Web browsers (Chrome, Firefox, Brave), email clients, messengers (Telegram, Discord), and network tools.
2. **`Office`**: Productivity suites (LibreOffice), text editors, calculators, document viewers, and IDEs.
3. **`Media`**: Media players (VLC, Totem), graphics software (GIMP, Inkscape), audio streamers (Spotify), and video recorders.
4. **`Games`**: Game launchers (Steam, Lutris, Heroic), emulators, and games (falls back to `Utilities` if no games are detected on the system).

### Creating Custom Folders
You can create as many custom folder drawers as you like:

1. Open your terminal or file manager and create a directory:
   ```bash
   mkdir -p ~/.config/wayplank/folders/"My Tools"
   ```
2. Simply **drag and drop** that folder from your file manager directly onto WayPlank.
3. WayPlank will instantly create a corresponding `.dockitem` and anchor the folder drawer to the dock.

### Adding and Managing Applications
To add applications to your folder drawer:
- **Via File Manager:** Navigate to `/usr/share/applications/` or `~/.local/share/applications/`, copy the `.desktop` files you want, and paste them (or symlink them) into your folder directory (`~/.config/wayplank/folders/<FolderName>/`).
- **Via Drag & Drop:** Drag an application `.desktop` file into the folder directory.

### Customizing Icons (Launchers, Folders & Docklets)
WayPlank provides an integrated, one-click icon personalization system directly from the dock:
1. **Right-click** on any application launcher, folder drawer, or docklet (`Preferences`, `Show Desktop`, `Session`, `Screenshot`, `Ejector`).
2. Select **Change Icon...** from the context menu.
3. The interactive **Icon Chooser** dialog will open:
   - **Live Theme Search:** Instant filtering across all 20,000+ icons in your active desktop theme.
   - **Browse File:** Select any custom image file (PNG, SVG, ICO, JPG) from your disk.
   - **Restore Default:** Reverts the item to its factory appearance.
4. Click **Apply** to update the icon immediately with zero restart needed.

> 💡 **Technical Note:** For application launchers, customizations follow the FreeDesktop standard (`~/.local/share/applications/`) without breaking Plank migration. For folders, icons are persisted using native GIO metadata (`metadata::custom-icon`), automatically recognized in Nautilus and Dolphin. For docklets, overrides are preserved in the `.dockitem` configuration.

---

## 4. Built-in Docklets & Accordion Mode

WayPlank includes 15 built-in docklets that provide live system controls and status indicators.

### Complete List of 15 Docklets

| Docklet URI | Description |
| :--- | :--- |
| `docklet://trash` | Trash can indicator with fill status, empty action, and drag-to-delete. |
| `docklet://desktop` | Show/Hide Desktop toggle (minimizes or unminimizes all windows). |
| `docklet://preferences` | One-click access to WayPlank Preferences dialog. |
| `docklet://network` | Live network connectivity monitor (Wi-Fi / Ethernet), signal strength, IP address inspection, and quick launch to network settings. |
| `docklet://volume` | Audio volume level with scroll-to-adjust and mute toggle. |
| `docklet://brightness` | Screen brightness control with scroll-to-adjust. |
| `docklet://battery` | Battery charge percentage and charging status for laptops. |
| `docklet://cpu` | Real-time CPU usage monitor meter. |
| `docklet://weather` | Real-time weather conditions and temperature. |
| `docklet://clock` | Classic analog clock showing system time. |
| `docklet://digital-clock` | Digital 12h/24h time display. |
| `docklet://mpris` | Media player controller (Play/Pause, Next, Previous track). |
| `docklet://screenshot` | Instant desktop screen capture utility. |
| `docklet://session` | Session controls (Lock screen, Log out, Suspend, Restart, Shut down). |
| `docklet://ejector` | Safe removal and unmounting of removable USB drives and volumes. |

### Accordion Mode (Space-Saving Collapsible Docklets)
When **Accordion Mode** is enabled (`accordion-docklets = true`), multiple docklets are collapsed into a single compact master slot on the dock.
- **Hover Expansion**: In standard mode, hovering over or dragging across the docklet section smoothly expands all active docklets. Moving the pointer away collapses them back into a single icon after the configured delay.
- **Click to Expand Mode**: In Preferences -> Appearance, enable **Click to Expand**. In this mode, hovering does not expand the docklets; instead, a single click on the master Preferences anchor toggles expansion, and a second click opens the Preferences dialog.
- **Configurable Collapse Delay**: Adjust the collapse countdown timer (0.5s to 20.0s) using the slider in Preferences -> Appearance.
- **Directional Indicators**: The Preferences anchor tooltip dynamically shows directional arrows (`▸` / `◂`) indicating whether the accordion is collapsed or expanded.
- **Intelligent Retention**: If the dock autohides or dodges while the accordion is expanded, returning within the delay window preserves the expanded state.
- **Modal Interaction Invalidation**: The accordion collapse timer is automatically paused while any dialog (Preferences, Shortcuts & Gestures, Icon Chooser, Weather) or popup menu is active.

To toggle Accordion Mode:
- Open **Preferences** (`Ctrl + Right-Click` on the dock $\rightarrow$ *Preferences*).
- Under the **Appearance / Items** tab, toggle **Accordion Docklets**.

### Configuring the Weather Docklet
The weather docklet fetches local meteorological data:
1. Edit or inspect `~/.config/wayplank/dock1/launchers/weather.dockitem`:
   ```ini
   [PlankDockItemPreferences]
   Launcher=docklet://weather

   [PlankWeatherDockItemPreferences]
   # Leave empty for automatic IP-based location, or enter your city name:
   City=Rome
   # Temperature unit: C (Celsius) or F (Fahrenheit)
   Units=C
   ```
2. Changes take effect immediately upon saving the file.

---

## 5. Categorization & Dynamic Separators

WayPlank features a smart sorting engine that eliminates dock clutter.

### Categorized Layout Order
When **Categorize Items** is enabled (`categorize-items = true`), WayPlank automatically arranges all items in a strictly defined sequence:

$$\text{Folders} \longrightarrow \text{Docklets} \longrightarrow \text{Pinned Apps} \longrightarrow \text{Running Apps} \longrightarrow \text{Trash}$$

- You can freely reorder items *within* their category group.
- Items are never mixed across categories accidentally.

### Permanent Trash Anchoring
The Trash docklet (`docklet://trash`) is permanently anchored to the far end of the dock (the right side on horizontal docks, or the bottom on vertical docks). Even if you drag or open new applications, Trash stays fixed at the edge, exactly where muscle memory expects it.

### Dynamic Separators
WayPlank automatically inserts subtle vertical separator lines between adjacent, non-empty category groups:
- If you have Folders, Docklets, and Apps active, two separators are placed: `[Folders] | [Docklets] | [Apps]`.
- When an unpinned application opens, a separator appears before it: `[Apps] | [Active App] | [Trash]`.
- When the application closes, the separator cleanly vanishes without animation stutter.

---

## 6. Mouse Gestures & Shortcuts

WayPlank offers an extensive set of mouse gestures and keyboard shortcuts designed for maximum productivity:

### Click Actions
- **Left Click**: Launch an application, or bring its existing window(s) to the foreground.
- **Middle Click** (or **Ctrl + Left Click**): Force launch a **NEW** instance of the application.
- **Right Click**: Open the application's context menu (displaying Desktop Actions / Quicklists, and "Keep in Dock").
- **Shift + Left Click**: Cycle focus to the next open window of that specific application.

### Scroll Gestures
- **Mouse Scroll on App Icon**: Smoothly cycle through all open windows of that application.
- **Ctrl + Mouse Scroll Up**: Dynamically increase dock icon size in real time.
- **Ctrl + Mouse Scroll Down**: Dynamically decrease dock icon size in real time.

### Drag & Drop Interactions
- **Drag icon off the dock**: Unpin and remove a launcher with a classic cartoon smoke ("poof") animation.
- **Drag icon along the dock**: Reorder launchers within their category.
- **Drop file onto an icon**: Directly open the dropped file in the target application.
- **Drop `.desktop` file or directory**: Pin a new application launcher or folder drawer.

### Quick Settings Access & In-App Help
- **Right Click (Any Item or Background)**: Instant access to **Shortcuts & Gestures...**, **Preferences...**, and **Quit**.
- **Ctrl + Right Click (Anywhere)**: Opens the WayPlank Preferences dialog directly, even when clicking over an active launcher icon.
- **Shortcuts & Gestures Dialog**: Visual reference dialog (`HelpWindow`) with categorized tabs explaining dock operations, gestures, and keyboard combinations.
- **Terminal CLI Cheatsheet**: Run `wayplank --help` in the terminal for a full, colorized quick-reference guide.
- **Right Click on empty dock space**: Opens the dock context menu.
- **Ctrl + Alt + Shift + Right Click**: Opens Developer Inspection Tools (launcher URI inspector, reload theme, inspect configuration).

---

## 7. Multi-Monitor & Wayland Desktop Integration

WayPlank is architected from the ground up for modern multi-monitor Wayland setups.

### Monitor Selection & Alignment
- **Position**: Place the dock on the `Bottom`, `Top`, `Left`, or `Right` edge of your screen.
- **Alignment**: Align the dock to `Center`, `Start` (Left/Top), or `End` (Right/Bottom).
- **Monitor Pinning**: In the Preferences dialog, select the exact physical output where WayPlank should appear (e.g., `eDP-1`, `DP-1`, `HDMI-A-1`).

### Intelligent Hide & Edge Pressure
- **Hide Modes**:
  - `None`: Dock stays permanently on screen and reserves desktop strut space.
  - `Intelligent`: Dock automatically slides out of view only when an active window overlaps its territory.
  - `Autohide`: Dock hides whenever the mouse leaves its boundary.
  - `Dodge Active Window`: Dock hides only when the focused window overlaps it.
- **Pressure Reveal**: Requires deliberate mouse pressure against the screen edge before the dock reveals itself, preventing accidental triggers when working near the border.

### GNOME Shell Mutter Extension Architecture
On GNOME Wayland sessions, WayPlank communicates with a dedicated, lightweight GNOME Shell extension:
- **Instantaneous 0.74s Startup**: Asynchronous initialization with zero synchronous evaluation freezes.
- **Stage Probing**: Multi-monitor boundaries are probed directly via Clutter stage coordinates, guaranteeing responsive mouse unhide even on secondary screens located at bottom or lateral coordinates.

---

## 8. Themes & Visual Customization

### Built-in Themes
WayPlank ships with five professionally designed themes:
1. **Arian Theme**: Modern dark translucent glass with subtle border illumination.
2. **Arian Theme Light**: Clean frosted glass designed for light desktop environments.
3. **Transparent**: Ultra-minimalist borderless design showing only floating icons.
4. **Matte**: Flat, modern solid finish.
5. **Default**: Classic Plank appearance.

### Installing Custom Themes
You can install third-party Plank themes simply by placing them in:
```bash
~/.local/share/plank/themes/<ThemeName>/dock.theme
```
They will instantly appear in the **Preferences $\rightarrow$ Theme** dropdown menu.

### Dock Size & Zoom Level
- **Icon Size**: Adjustable from 24px up to 128px.
- **Icon Zoom (Magnification)**: When enabled, icons smoothly magnify up to 200% under the mouse cursor, with physics-based smooth interpolation.

---

## 9. Command Line Usage & Configuration Files

### CLI Commands
```bash
# Start WayPlank
wayplank

# Open the Preferences dialog directly
wayplank --preferences

# Run in debug mode with verbose logging
wayplank -d

# Show current version and build information
wayplank --version
```

### Configuration File Paths
- **Launchers Directory**: `~/.config/wayplank/dock1/launchers/`
- **Folder Drawers**: `~/.config/wayplank/folders/`
- **Custom Themes**: `~/.local/share/plank/themes/`
- **Cache & Temporary Files**: `~/.cache/wayplank/`

### GSettings Database Keys
All settings are stored in the GSettings schema `net.launchpad.plank.dock.settings:/net/launchpad/plank/docks/dock1/`:
```bash
# Read all current dock settings
gsettings list-recursively net.launchpad.plank.dock.settings:/net/launchpad/plank/docks/dock1/

# Toggle categorized items
gsettings set net.launchpad.plank.dock.settings:/net/launchpad/plank/docks/dock1/ categorize-items true

# Toggle accordion docklets
gsettings set net.launchpad.plank.dock.settings:/net/launchpad/plank/docks/dock1/ accordion-docklets true

# Change dock theme
gsettings set net.launchpad.plank.dock.settings:/net/launchpad/plank/docks/dock1/ theme 'Arian Theme Light'
```

---

## 10. Troubleshooting & FAQ

#### Q: How do I open Preferences if the preferences icon is missing?
**A:** Hold the **`Ctrl`** key and **Right-Click** anywhere on the dock, or run `wayplank --preferences` in a terminal.

#### Q: How do I add an application that is not in the default folders?
**A:** Open your Application Menu in GNOME or your file manager at `/usr/share/applications/`, and simply drag the `.desktop` file onto WayPlank.

#### Q: Can I reset WayPlank to its initial default state?
**A:** Yes. Close WayPlank, remove the configuration folder, and start WayPlank again:
```bash
killall wayplank
rm -rf ~/.config/wayplank/dock1/
wayplank &
```
WayPlank will automatically regenerate the clean modern defaults with folders, docklets, and pinned applications.

---

*WayPlank is free software licensed under the GNU General Public License v3.*  
*Copyright © 2011–2015 Plank Developers | Copyright © 2026 Sergio Melas & WayPlank Contributors.*

