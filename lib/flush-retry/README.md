# wl_flush_retry (scheme A)

Small `LD_PRELOAD` shared library used **only** by `kde-dockbar`.

## Problem

On KDE Plasma Wayland, GTK3/GDK aborts the process when `wl_display_flush()`
returns `EAGAIN` / `EWOULDBLOCK`:

```
Error flushing display: Resource temporarily unavailable
```

That is a transient compositor write-buffer back-pressure condition, but GDK
treats it as fatal (`_exit`). Thumbnail / animation commit bursts make it easy
to hit.

## What this does

Intercepts `wl_display_flush`:

1. Call the real `wl_display_flush`.
2. On `EAGAIN`/`EWOULDBLOCK`, `poll(POLLOUT)` on the display fd and retry.
3. Cap total wait (default **400ms**, slice **10ms**).
4. If still failing after the cap, return the real error (GDK may still exit).

**Honest scope:** scheme A stops `_exit` on *transient* flush EAGAIN by retrying.
It does **not** rewrite GDK; a persistently blocked Wayland socket can still kill
the dock after the cap.

## Build / install

From the project root (also done by `BuildBin.sh`):

```bash
gcc -shared -fPIC -O2 -Wall \
  -o build/libwl_flush_retry.so \
  lib/flush-retry/wl_flush_retry.c -ldl
install -Dm755 build/libwl_flush_retry.so \
  ~/.local/lib/kde-dockbar/libwl_flush_retry.so
```

## Wire-up (kde-dockbar only)

`~/.config/systemd/user/kde-dockbar.service` (and `data/kde-dockbar.service`):

```ini
Environment=LD_PRELOAD=%h/.local/lib/kde-dockbar/libwl_flush_retry.so
```

Optional tuning:

```ini
Environment=KDE_DOCKBAR_FLUSH_RETRY_MS=400
Environment=KDE_DOCKBAR_FLUSH_RETRY_SLICE_MS=10
```

## Verify

```bash
systemctl --user restart kde-dockbar.service
PID=$(systemctl --user show -p MainPID --value kde-dockbar.service)
# maps should list the .so
grep wl_flush_retry /proc/$PID/maps
# or:
LD_DEBUG=libs kde-dockbar 2>&1 | grep wl_flush_retry
```
