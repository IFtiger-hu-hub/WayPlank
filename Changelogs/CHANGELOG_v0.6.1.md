# Wayplank V0.6.1 Detailed Technical Changelog

Release Milestone: **V0.6.1 (KWin Multi-Monitor Brightness Synchronization & Display Output Hardening)**  
Release Date: 2026-10-13  
Author & Maintainer: Sergio Melas (sergiomelas@gmail.com)  

---

## 1. 📋 Overview & Motivation

Wayplank **V0.6.1** addresses a critical multi-monitor hardware integration bug under **KDE Plasma (KWin)**, where adjusting the brightness via the Screen Brightness docklet (`docklet://brightness`) only adjusted a subset of connected monitors (e.g. 2 out of 3 displays).

### The Root Cause
1. **PowerDevil User-Space Limitation**: Under KDE Plasma 6, Wayplank previously relied on calling `org.kde.Solid.PowerManagement.Actions.BrightnessControl.setBrightness(...)` via D-Bus. In user space, PowerDevil attempts to open direct I2C DDC/CI buses (`/dev/i2c-*`). When user permissions are not granted (e.g. user not in `i2c` group), PowerDevil fails with `EACCES (-13: Permission denied)` and silently drops DDC support for external secondary monitors (such as HDMI/DisplayPort QHD/4K screens). As a result, PowerDevil only registers and adjusts internal panels and the primary display.
2. **KWin Compositor DRM Privileges**: Unlike user-space PowerDevil, the KWin Wayland compositor operates with direct kernel DRM privileges, retaining full native brightness control across all connected outputs (`kscreen-doctor -o` reports `Brightness control: supported` across all displays).
3. **Atomic Multi-Output Adjustment**: In v0.6.1, Wayplank introduces dynamic output discovery via `kscreen-doctor -j`, dynamically caching all active display outputs (`DP-5`, `DP-6`, `eDP-1`, etc.) and issuing an atomic multi-output brightness adjustment command via `kscreen-doctor output.<name1>.brightness.<val> output.<name2>.brightness.<val> ...` whenever brightness changes, while concurrently updating PowerDevil D-Bus to maintain power profile synchronization and OSD indicators.

---

## 2. 🛡️ Architectural Safety & Compositor Isolation

- **KWin Specificity**: The `kscreen-doctor` execution path is strictly guarded with `if (kde_available && GLib.Environment.find_program_in_path ("kscreen-doctor") != null)`.
- **GNOME (Mutter) Immunity**: On GNOME sessions, `kde_available` evaluates to `false`. Wayplank continues using the native `org.gnome.SettingsDaemon.Power` D-Bus interface without invoking external binaries.
- **Labwc (wlroots) Immunity**: On Labwc sessions, `kde_available` evaluates to `false`. Wayplank continues utilizing `brightnessctl`, `light`, or direct logind D-Bus methods.
- **HAL Zero-Touch Guarantee**: No Hardware Abstraction Layer or backend files (`lib/Services/*`) were modified. All logic is strictly encapsulated within `lib/Items/BrightnessDockItem.vala`.

---

## 3. 🗂️ File Changes Summary

| File | Changes Made |
| :--- | :--- |
| `include/config.h` | Bumped `VERSION` and `PACKAGE_VERSION` to `0.6.1`, updated `VERSION_INFO` to `"Wayplank 0.6.1 - Release Build"`. |
| `BuildDeb.sh` | Bumped `PKG_VER` to `"0.6.1"` for native Debian package building. |
| `lib/Items/BrightnessDockItem.vala` | Implemented `refresh_kscreen_outputs()` with `kscreen-doctor -j` JSON parsing, connected `Gdk.Display.monitor_added` and `monitor_removed` signals, and added atomic multi-output `kscreen-doctor` execution in `apply_hardware_brightness()`. |
| `README.md` | Updated release badge to v0.6.1 and added concise v0.6.1 release note in Release Highlights. |

---

## 4. 📦 Validation & Build Artifacts

- **Native Binary**: Compiled and verified via `BuildDeb.sh`:
  - Path: `build/wayplank`
  - Version: `Wayplank 0.6.1`
- **Debian Package**: Generated and verified via `BuildDeb.sh`:
  - Path: `build/wayplank_0.6.1_amd64.deb`
- **Multi-Monitor Verification**: Tested across 3 connected displays (`DP-6` LG Ultra HD, `DP-5` LG HDR QHD, `eDP-1` Built-in Panel), verifying simultaneous 100% synchronization across all 3 displays with zero dropped I2C transactions.

