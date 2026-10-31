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
set -euo pipefail

# --- Dolphin Auto-Spawn GUI Terminal ---
if [ ! -t 0 ] && [ -z "${VSCODE_INJECTION:-}" ] && [ -z "${DOCKBAR_NO_PROMPT:-}" ]; then
    if command -v konsole >/dev/null 2>&1; then
        exec konsole -e bash "$0" "$@"
    elif command -v x-terminal-emulator >/dev/null 2>&1; then
        exec x-terminal-emulator -e bash "$0" "$@"
    fi
fi

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${BASE_DIR}/build"
mkdir -p "$OUT_DIR"
rm -f "${OUT_DIR}/kde-dockbar"

echo "⚙️ Compiling GLib schemas & resources..."
if command -v glib-compile-schemas >/dev/null 2>&1; then
    glib-compile-schemas "${BASE_DIR}/data/glib-2.0/schemas"
fi
glib-compile-resources \
    --sourcedir="${BASE_DIR}/data" \
    --target="${BASE_DIR}/lib/resources.c" \
    --generate-source \
    "${BASE_DIR}/data/plank.gresource.xml"

if [ -f "${BASE_DIR}/data/protocols/plasma-window-management.xml" ]; then
    if [ ! -f "${BASE_DIR}/lib/plasma-window-management-client.h" ] || [ ! -f "${BASE_DIR}/lib/plasma-window-management-protocol.c" ]; then
        echo "⚙️ Generating Wayland plasma-window-management protocol bindings..."
        wayland-scanner client-header "${BASE_DIR}/data/protocols/plasma-window-management.xml" "${BASE_DIR}/lib/plasma-window-management-client.h"
        wayland-scanner private-code "${BASE_DIR}/data/protocols/plasma-window-management.xml" "${BASE_DIR}/lib/plasma-window-management-protocol.c"
    fi
fi

echo "🛡️  Building wl_flush_retry LD_PRELOAD (scheme A)..."
gcc -shared -fPIC -O2 -Wall \
    -o "${OUT_DIR}/libwl_flush_retry.so" \
    "${BASE_DIR}/lib/flush-retry/wl_flush_retry.c" -ldl
mkdir -p "${HOME}/.local/lib/kde-dockbar"
install -m755 "${OUT_DIR}/libwl_flush_retry.so" \
    "${HOME}/.local/lib/kde-dockbar/libwl_flush_retry.so"
echo "✅ Preload ready: ${HOME}/.local/lib/kde-dockbar/libwl_flush_retry.so"

echo "🏗️ Compiling Vala & C sources to native binary (KDE Plasma Native)..."
mapfile -t VALA_FILES < <(find "${BASE_DIR}/lib" "${BASE_DIR}/src" -name "*.vala")

C_SOURCES=("${BASE_DIR}/lib/resources.c")
if [ -f "${BASE_DIR}/lib/gtk-compat.c" ]; then
    C_SOURCES+=("${BASE_DIR}/lib/gtk-compat.c")
fi
if [ -f "${BASE_DIR}/lib/plasma-window-management-protocol.c" ]; then
    C_SOURCES+=("${BASE_DIR}/lib/plasma-window-management-protocol.c")
fi
if [ -f "${BASE_DIR}/lib/Services/KWinPlasmaWindow.c" ]; then
    C_SOURCES+=("${BASE_DIR}/lib/Services/KWinPlasmaWindow.c")
fi

if valac -g \
    --gresources="${BASE_DIR}/data/plank.gresource.xml" \
    --gresourcesdir="${BASE_DIR}/data" \
    --vapidir="${BASE_DIR}/vapi" \
    --pkg posix \
    --pkg gio-unix-2.0 \
    --pkg gtk+-3.0 \
    --pkg gtk-layer-shell-0 \
    --pkg json-glib-1.0 \
    --pkg gee-0.8 \
    --pkg compat \
    --pkg config \
    -X -D_GNU_SOURCE \
    -X "-Dsetproctitle(x)=" \
    -X -DGETTEXT_PACKAGE=\"kde-dockbar\" \
    -X -I"${BASE_DIR}/lib" \
    -X -I"${BASE_DIR}/lib/Services" \
    -X -I"${BASE_DIR}/include" \
    -X -w \
    -X -lm \
    -X -lwayland-client \
    "${VALA_FILES[@]}" \
    "${C_SOURCES[@]}" \
    -o "${OUT_DIR}/kde-dockbar"; then
    rm -f "${BASE_DIR}/lib/resources.c"
    echo "✅ Binary ready: ${OUT_DIR}/kde-dockbar"
    if [ -t 0 ] && [ -z "${DOCKBAR_NO_PROMPT:-}" ] && [ -z "${VSCODE_INJECTION:-}" ] && [ -z "${CI:-}" ] && [ -z "${NONINTERACTIVE:-}" ]; then
        read -rp "👋 Press Enter to close..."
    fi
else
    rm -f "${BASE_DIR}/lib/resources.c"
    echo ""
    echo "❌ Error: Compilation failed!"
    if [ -t 0 ] && [ -z "${DOCKBAR_NO_PROMPT:-}" ] && [ -z "${VSCODE_INJECTION:-}" ] && [ -z "${CI:-}" ] && [ -z "${NONINTERACTIVE:-}" ]; then
        read -rp "👋 Press Enter to close..."
    fi
    exit 1
fi
