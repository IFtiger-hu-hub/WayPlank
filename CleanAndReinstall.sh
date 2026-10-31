#!/usr/bin/env bash
#
#  Copyright (C) 2026 史有虎 (IFtiger-hu)
#
#  This file is part of kde-dockbar.
#
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🏗️ 1. 编译最新的原生二进制..."
NONINTERACTIVE=1 bash "${BASE_DIR}/BuildBin.sh"

echo "🛑 2. 正在停止当前运行的旧 dockbar 服务与遗留进程..."
systemctl --user stop "kde-dockbar.service" 2>/dev/null || true
systemctl --user stop "app-kde*dockbar*.service" 2>/dev/null || true
systemctl --user reset-failed kde-dockbar 2>/dev/null || true
pkill -9 -x kde-dockbar 2>/dev/null || true
sleep 1

echo "🧹 3. 正在清理本地缓存、旧配置文件与 dconf 数据..."
rm -rf "${HOME}/.config/kde-dockbar"
rm -rf "${HOME}/.cache/kde-dockbar"
rm -rf "${HOME}/.local/share/kde-dockbar"
if command -v dconf >/dev/null 2>&1; then
    dconf reset -f /net/launchpad/plank/ || true
fi

echo "📦 4. 更新安装本地运行文件..."
mkdir -p "${HOME}/.local/bin" "${HOME}/.config/systemd/user" "${HOME}/.local/lib/kde-dockbar"
cp -f "${BASE_DIR}/build/kde-dockbar" "${HOME}/.local/bin/kde-dockbar"
chmod +x "${HOME}/.local/bin/kde-dockbar"
if [ -f "${BASE_DIR}/build/libwl_flush_retry.so" ]; then
    install -m755 "${BASE_DIR}/build/libwl_flush_retry.so" \
        "${HOME}/.local/lib/kde-dockbar/libwl_flush_retry.so"
fi
if [ -f "${BASE_DIR}/data/kde-dockbar.service" ]; then
    install -m644 "${BASE_DIR}/data/kde-dockbar.service" \
        "${HOME}/.config/systemd/user/kde-dockbar.service"
fi

echo "🚀 5. 重启全新的独立 kde-dockbar..."
systemctl --user daemon-reload 2>/dev/null || true
systemctl --user reset-failed kde-dockbar.service 2>/dev/null || true
if systemctl --user start kde-dockbar.service 2>/dev/null; then
    :
else
    systemd-run --user --unit=kde-dockbar --slice=app.slice "${HOME}/.local/bin/kde-dockbar" >/dev/null 2>&1 || {
        nohup "${HOME}/.local/bin/kde-dockbar" >/dev/null 2>&1 &
    }
fi
sleep 1

echo ""
echo "✅ 重置与启动完成！"
echo "─────────────────────────────────────────────────────────────"
echo "📌 关键提醒："
echo "   现在所有应用均通过 KDE 原生 'kstart' 网关启动，"
echo "   每个应用都会被分配至独立的原生 cgroup 服务中。"
echo "   之前在旧服务遗留的 Edge 渲染进程，请在关闭 Edge 窗口后"
echo "   通过 Dock 栏重新打开，即可看到其完全独立在 Chromium 名下！"
echo "─────────────────────────────────────────────────────────────"
