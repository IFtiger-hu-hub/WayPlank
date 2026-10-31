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

#include "kwin-plasma-window.h"
#include "plasma-window-management-client.h"

#include <gdk/gdkwayland.h>
#include <wayland-client.h>

static struct wl_display *s_wl_display = NULL;
static struct wl_registry *s_wl_registry = NULL;
static struct org_kde_plasma_window_management *s_plasma_mgmt = NULL;
static struct wl_surface *s_panel_surface = NULL;
static GtkWidget *s_dock_widget = NULL;

/* Hash table mapping uuid string -> struct org_kde_plasma_window * */
static GHashTable *s_window_proxies = NULL;

static void dummy_cb (void) {}

static const struct org_kde_plasma_window_listener s_window_listener = {
	.title_changed = (void *) dummy_cb,
	.app_id_changed = (void *) dummy_cb,
	.state_changed = (void *) dummy_cb,
	.virtual_desktop_changed = (void *) dummy_cb,
	.themed_icon_name_changed = (void *) dummy_cb,
	.unmapped = (void *) dummy_cb,
	.initial_state = (void *) dummy_cb,
	.parent_window = (void *) dummy_cb,
	.geometry = (void *) dummy_cb,
	.icon_changed = (void *) dummy_cb,
	.pid_changed = (void *) dummy_cb,
	.virtual_desktop_entered = (void *) dummy_cb,
	.virtual_desktop_left = (void *) dummy_cb,
	.application_menu = (void *) dummy_cb,
	.activity_entered = (void *) dummy_cb,
	.activity_left = (void *) dummy_cb,
	.resource_name_changed = (void *) dummy_cb,
	.client_geometry = (void *) dummy_cb,
};

static void destroy_plasma_window_proxy (gpointer data)
{
	struct org_kde_plasma_window *win = (struct org_kde_plasma_window *) data;
	if (win) {
		org_kde_plasma_window_destroy (win);
	}
}

static void on_mgmt_window_with_uuid (void *data,
                                     struct org_kde_plasma_window_management *m,
                                     uint32_t id,
                                     const char *uuid)
{
	/* Window announcement from compositor */
	(void) data;
	(void) m;
	(void) id;
	(void) uuid;
}

static const struct org_kde_plasma_window_management_listener s_mgmt_listener = {
	.show_desktop_changed = (void *) dummy_cb,
	.window = (void *) dummy_cb,
	.stacking_order_changed = (void *) dummy_cb,
	.stacking_order_uuid_changed = (void *) dummy_cb,
	.window_with_uuid = on_mgmt_window_with_uuid,
	.stacking_order_changed_2 = (void *) dummy_cb,
};

static void registry_global_handler (void *data,
                                    struct wl_registry *registry,
                                    uint32_t id,
                                    const char *interface,
                                    uint32_t version)
{
	(void) data;
	if (g_strcmp0 (interface, org_kde_plasma_window_management_interface.name) == 0) {
		uint32_t ver = (version < 16) ? version : 16;
		s_plasma_mgmt = wl_registry_bind (registry, id, &org_kde_plasma_window_management_interface, ver);
		if (s_plasma_mgmt) {
			org_kde_plasma_window_management_add_listener (s_plasma_mgmt, &s_mgmt_listener, NULL);
		}
	}
}

static void registry_global_remove (void *data, struct wl_registry *registry, uint32_t id)
{
	(void) data;
	(void) registry;
	(void) id;
}

static const struct wl_registry_listener s_registry_listener = {
	.global = registry_global_handler,
	.global_remove = registry_global_remove
};

static void on_dock_unmap (GtkWidget *widget, gpointer user_data)
{
	(void) widget;
	(void) user_data;
	s_panel_surface = NULL;
	if (s_window_proxies) {
		g_hash_table_remove_all (s_window_proxies);
	}
}

static struct wl_surface *get_valid_panel_surface (void)
{
	if (!s_dock_widget)
		return NULL;
	
	if (!gtk_widget_get_realized (s_dock_widget) || !gtk_widget_get_mapped (s_dock_widget)) {
		s_panel_surface = NULL;
		return NULL;
	}

	GdkWindow *gdk_win = gtk_widget_get_window (s_dock_widget);
	if (!gdk_win || !GDK_IS_WAYLAND_WINDOW (gdk_win)) {
		s_panel_surface = NULL;
		return NULL;
	}

	struct wl_surface *surf = gdk_wayland_window_get_wl_surface (gdk_win);
	if (!surf) {
		s_panel_surface = NULL;
		return NULL;
	}

	if (surf != s_panel_surface) {
		/* 当切换屏幕或窗口重建导致 surface 发生变化时，旧代理中的 surface 绑定已失效，
		 * 必须清空代理缓存重新绑定，彻底防止向 KWin 传递 unknown object (已销毁的 surface) 导致崩溃！ */
		if (s_window_proxies) {
			g_hash_table_remove_all (s_window_proxies);
		}
		s_panel_surface = surf;
	}

	return s_panel_surface;
}

void kwin_dock_invalidate_surface (void)
{
	s_panel_surface = NULL;
	if (s_window_proxies) {
		g_hash_table_remove_all (s_window_proxies);
	}
}

static void on_dock_realize (GtkWidget *widget, gpointer user_data)
{
	(void) widget;
	(void) user_data;
	get_valid_panel_surface ();
}

void kwin_dock_init_plasma_window_management (GtkWidget *dock_window)
{
	if (s_plasma_mgmt)
		return;

	GdkDisplay *gdk_disp = gdk_display_get_default ();
	if (!gdk_disp || !GDK_IS_WAYLAND_DISPLAY (gdk_disp)) {
		return;
	}

	s_wl_display = gdk_wayland_display_get_wl_display (gdk_disp);
	if (!s_wl_display)
		return;

	s_dock_widget = dock_window;
	g_signal_connect (dock_window, "unmap", G_CALLBACK (on_dock_unmap), NULL);
	g_signal_connect (dock_window, "unrealize", G_CALLBACK (on_dock_unmap), NULL);
	if (gtk_widget_get_realized (dock_window)) {
		get_valid_panel_surface ();
	} else {
		g_signal_connect (dock_window, "realize", G_CALLBACK (on_dock_realize), NULL);
	}

	s_window_proxies = g_hash_table_new_full (g_str_hash, g_str_equal, g_free, destroy_plasma_window_proxy);

	s_wl_registry = wl_display_get_registry (s_wl_display);
	wl_registry_add_listener (s_wl_registry, &s_registry_listener, NULL);
	wl_display_roundtrip (s_wl_display);
}

void kwin_dock_cleanup_plasma_window_management (void)
{
	if (s_window_proxies) {
		g_hash_table_destroy (s_window_proxies);
		s_window_proxies = NULL;
	}
	if (s_plasma_mgmt) {
		org_kde_plasma_window_management_destroy (s_plasma_mgmt);
		s_plasma_mgmt = NULL;
	}
	if (s_wl_registry) {
		wl_registry_destroy (s_wl_registry);
		s_wl_registry = NULL;
	}
	s_panel_surface = NULL;
	s_dock_widget = NULL;
	s_wl_display = NULL;
}

static struct org_kde_plasma_window *get_or_create_window_proxy (const char *uuid)
{
	if (!s_plasma_mgmt || !uuid || !uuid[0])
		return NULL;

	struct org_kde_plasma_window *win = g_hash_table_lookup (s_window_proxies, uuid);
	if (win)
		return win;

	win = org_kde_plasma_window_management_get_window_by_uuid (s_plasma_mgmt, uuid);
	if (!win)
		return NULL;

	char *uuid_key = g_strdup (uuid);
	org_kde_plasma_window_add_listener (win, &s_window_listener, NULL);
	g_hash_table_insert (s_window_proxies, uuid_key, win);
	return win;
}

void kwin_dock_prune_window_proxies (const char **active_uuids, int count)
{
	if (!s_window_proxies)
		return;

	GHashTableIter iter;
	gpointer key, value;
	GList *to_remove = NULL;

	g_hash_table_iter_init (&iter, s_window_proxies);
	while (g_hash_table_iter_next (&iter, &key, &value)) {
		const char *uuid = (const char *) key;
		gboolean found = FALSE;
		for (int i = 0; i < count; i++) {
			if (active_uuids[i] && g_strcmp0 (uuid, active_uuids[i]) == 0) {
				found = TRUE;
				break;
			}
		}
		if (!found) {
			to_remove = g_list_prepend (to_remove, key);
		}
	}

	for (GList *l = to_remove; l != NULL; l = l->next) {
		g_hash_table_remove (s_window_proxies, l->data);
	}
	g_list_free (to_remove);
}

void kwin_dock_set_window_minimized_geometry (const char *uuid, int x, int y, int width, int height)
{
	struct wl_surface *panel_surf = get_valid_panel_surface ();
	if (!panel_surf)
		return;

	if (!uuid || !uuid[0] || width <= 0 || height <= 0)
		return;

	struct org_kde_plasma_window *win = get_or_create_window_proxy (uuid);
	if (!win)
		return;

	org_kde_plasma_window_set_minimized_geometry (win, panel_surf,
	                                             (uint32_t) x, (uint32_t) y,
	                                             (uint32_t) width, (uint32_t) height);
	if (s_wl_display) {
		wl_display_flush (s_wl_display);
	}
}

void kwin_dock_unset_window_minimized_geometry (const char *uuid)
{
	struct wl_surface *panel_surf = get_valid_panel_surface ();
	if (!panel_surf || !uuid || !uuid[0])
		return;

	struct org_kde_plasma_window *win = get_or_create_window_proxy (uuid);
	if (!win)
		return;

	org_kde_plasma_window_unset_minimized_geometry (win, panel_surf);
	if (s_wl_display) {
		wl_display_flush (s_wl_display);
	}
}
