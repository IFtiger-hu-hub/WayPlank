/*
 *  Copyright (C) 2026 史有虎 (IFtiger-hu)
 *
 *  This file is part of kde-dockbar.
 *
 *  kde-dockbar is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 */

#ifndef KWIN_PLASMA_WINDOW_H
#define KWIN_PLASMA_WINDOW_H

#include <gtk/gtk.h>

G_BEGIN_DECLS

void kwin_dock_init_plasma_window_management (GtkWidget *dock_window);
void kwin_dock_cleanup_plasma_window_management (void);
void kwin_dock_set_window_minimized_geometry (const char *uuid, int x, int y, int width, int height);
void kwin_dock_unset_window_minimized_geometry (const char *uuid);
void kwin_dock_prune_window_proxies (const char **active_uuids, int count);
void kwin_dock_invalidate_surface (void);

G_END_DECLS

#endif /* KWIN_PLASMA_WINDOW_H */
