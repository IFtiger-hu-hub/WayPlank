#!/usr/bin/env bash
#
#  Copyright (C) 2026 史有虎 (IFtiger-hu)
#
#  This file is part of kde-dockbar.
#
#  kde-dockbar is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
# ==============================================================================
# Clean RPM Builder for kde-dockbar (Fedora / openSUSE / RHEL)
# ==============================================================================
set -euo pipefail

# --- Dolphin Auto-Spawn GUI Terminal ---
if [ ! -t 0 ] && [ -z "${VSCODE_INJECTION:-}" ] && [ -z "${DOCKBAR_NO_PROMPT:-}" ] && [ -z "${CI:-}" ] && [ -z "${NONINTERACTIVE:-}" ]; then
    if command -v konsole >/dev/null 2>&1; then
        exec konsole -e bash "$0" "$@"
    elif command -v x-terminal-emulator >/dev/null 2>&1; then
        exec x-terminal-emulator -e bash "$0" "$@"
    fi
fi

if ! command -v rpmbuild >/dev/null 2>&1; then
    echo "❌ Error: 'rpmbuild' is not installed."
    echo "   • Fedora:    sudo dnf install rpm-build"
    echo "   • openSUSE:  sudo zypper install rpm-build"
    if [ -t 0 ] && [ -z "${DOCKBAR_NO_PROMPT:-}" ] && [ -z "${VSCODE_INJECTION:-}" ] && [ -z "${CI:-}" ] && [ -z "${NONINTERACTIVE:-}" ]; then
        read -rp "👋 Press Enter to close..."
    fi
    exit 1
fi

PKG_NAME="kde-dockbar"
PKG_VER="0.1.0"
PKG_REL="1"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RPM_TOPDIR="${BASE_DIR}/build_rpm_workspace"
OUT_DIR="${BASE_DIR}/build"
ARCH="$(uname -m)"

echo ""
echo "🚀 kde-dockbar Builder — V${PKG_VER} (KDE Plasma Native RPM)"
echo "─────────────────────────────────────────────────────────────"
echo ""

# 1. Call the binary build script (BuildBin.sh)
if [ -f "${BASE_DIR}/BuildBin.sh" ]; then
    if ! DOCKBAR_NO_PROMPT=1 bash "${BASE_DIR}/BuildBin.sh"; then
        echo "❌ Build failed! Compilation error in BuildBin.sh"
        exit 1
    fi
else
    echo "❌ Error: BuildBin.sh not found!"
    exit 1
fi

rm -rf "$RPM_TOPDIR"
mkdir -p "$RPM_TOPDIR"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

echo "📦 Preparing RPM source payloads..."
cp "${OUT_DIR}/kde-dockbar" "${RPM_TOPDIR}/SOURCES/kde-dockbar"
cp -r "${BASE_DIR}/data/themes" "${RPM_TOPDIR}/SOURCES/"
cp -r "${BASE_DIR}/data/icons" "${RPM_TOPDIR}/SOURCES/"
cp "${BASE_DIR}/data/kde-dockbar.svg" "${RPM_TOPDIR}/SOURCES/kde-dockbar.svg"
cp "${BASE_DIR}/data/kde-dockbar.desktop" "${RPM_TOPDIR}/SOURCES/kde-dockbar.desktop"
cp "${BASE_DIR}/data/glib-2.0/schemas/net.launchpad.plank.gschema.xml" "${RPM_TOPDIR}/SOURCES/net.launchpad.plank.gschema.xml"

cat << EOF > "${RPM_TOPDIR}/SPECS/${PKG_NAME}.spec"
%define _binary_payload w19.zstdio
%define _source_payload w19.zstdio
%define debug_package %{nil}

Name:           ${PKG_NAME}
Version:        ${PKG_VER}
Release:        ${PKG_REL}
Summary:        Modern native dock for KDE Plasma Wayland
License:        GPL-3.0-or-later
Group:          System/GUI/KDE
URL:            https://github.com/IFtiger-hu-hub/WayPlank
Recommends:     spectacle, plasma-systemmonitor, ddcutil, brightnessctl

%description
kde-dockbar is a lightweight, high-performance dock designed exclusively
for KDE Plasma on Wayland using native GtkLayerShell and KWin D-Bus integration.

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}%{_bindir}
mkdir -p %{buildroot}%{_datadir}/applications
mkdir -p %{buildroot}%{_datadir}/kde-dockbar/themes
mkdir -p %{buildroot}%{_datadir}/icons/hicolor/scalable/apps
mkdir -p %{buildroot}%{_datadir}/glib-2.0/schemas
mkdir -p %{buildroot}%{_datadir}/doc/kde-dockbar

cp %{_sourcedir}/kde-dockbar %{buildroot}%{_bindir}/kde-dockbar

cp -r %{_sourcedir}/themes/* %{buildroot}%{_datadir}/kde-dockbar/themes/
cp -r %{_sourcedir}/icons/* %{buildroot}%{_datadir}/icons/hicolor/
cp %{_sourcedir}/kde-dockbar.svg %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/kde-dockbar.svg

cp %{_sourcedir}/net.launchpad.plank.gschema.xml %{buildroot}%{_datadir}/glib-2.0/schemas/
cp %{_sourcedir}/kde-dockbar.desktop %{buildroot}%{_datadir}/applications/kde-dockbar.desktop

%post
if command -v glib-compile-schemas >/dev/null 2>&1; then
    glib-compile-schemas %{_datadir}/glib-2.0/schemas/ || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t -f %{_datadir}/icons/hicolor >/dev/null 2>&1 || true
fi
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database -q %{_datadir}/applications/ || true
fi

%postun
if command -v glib-compile-schemas >/dev/null 2>&1; then
    glib-compile-schemas %{_datadir}/glib-2.0/schemas/ || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t -f %{_datadir}/icons/hicolor >/dev/null 2>&1 || true
fi
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database -q %{_datadir}/applications/ || true
fi

%files
%{_bindir}/kde-dockbar
%{_datadir}/applications/kde-dockbar.desktop
%{_datadir}/kde-dockbar
%{_datadir}/icons/hicolor/*
%{_datadir}/glib-2.0/schemas/net.launchpad.plank.gschema.xml

%changelog
* Wed Oct 28 2026 Youhu Shi (史有虎) - ${PKG_VER}-${PKG_REL}
- Initial minimal viable release of kde-dockbar tailored specifically for KDE Plasma

EOF

echo "📦 Building RPM package..."
rpmbuild --define "_topdir ${RPM_TOPDIR}" --define "_dbpath ${RPM_TOPDIR}/rpmdb" -bb "${RPM_TOPDIR}/SPECS/${PKG_NAME}.spec" > /dev/null

GENERATED_RPM="$(find "${RPM_TOPDIR}/RPMS" -name "*.rpm" | head -n 1)"
if [ -n "$GENERATED_RPM" ] && [ -f "$GENERATED_RPM" ]; then
    TARGET_RPM="${OUT_DIR}/$(basename "$GENERATED_RPM")"
    cp "$GENERATED_RPM" "$TARGET_RPM"
    rm -rf "$RPM_TOPDIR"
    echo ""
    echo "🎉 RPM Package built successfully!"
    echo "📦 Package: ${TARGET_RPM}"
    echo "💡 Install with: sudo dnf install \"${TARGET_RPM}\""
    echo "                 or: sudo zypper install \"${TARGET_RPM}\""
    echo "                 or: sudo rpm -Uvh \"${TARGET_RPM}\""
    echo ""
else
    echo "❌ Build failed! No RPM package generated."
    rm -rf "$RPM_TOPDIR"
    if [ -t 0 ] && [ -z "${DOCKBAR_NO_PROMPT:-}" ] && [ -z "${CI:-}" ] && [ -z "${NONINTERACTIVE:-}" ]; then
        read -rp "👋 Press Enter to close..."
    fi
    exit 1
fi

if [ -t 0 ] && [ -z "${DOCKBAR_NO_PROMPT:-}" ] && [ -z "${CI:-}" ] && [ -z "${NONINTERACTIVE:-}" ]; then
    read -rp "👋 Press Enter to close..."
fi
