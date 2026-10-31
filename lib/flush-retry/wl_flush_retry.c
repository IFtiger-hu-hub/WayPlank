/*
 * wl_flush_retry — LD_PRELOAD helper for kde-dockbar only.
 *
 * GDK Wayland calls _exit(1) when wl_display_flush() returns EAGAIN/EWOULDBLOCK
 * ("Error flushing display"). That turns a transient compositor back-pressure
 * condition into a hard dock crash.
 *
 * Scheme A: intercept wl_display_flush. On EAGAIN/EWOULDBLOCK, poll the display
 * fd for POLLOUT and retry until success or a time/retry cap, then return the
 * real error so GDK can still exit if the socket is truly stuck.
 *
 * Honest limit: stops _exit on *transient* EAGAIN by absorbing brief
 * back-pressure. If the cap is exhausted, GDK still aborts.
 *
 * Built without wayland-client headers (opaque pointers + dlsym only).
 */

#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <poll.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#ifndef WL_FLUSH_RETRY_DEFAULT_MAX_MS
#define WL_FLUSH_RETRY_DEFAULT_MAX_MS 400
#endif
#ifndef WL_FLUSH_RETRY_DEFAULT_SLICE_MS
#define WL_FLUSH_RETRY_DEFAULT_SLICE_MS 10
#endif

/* Opaque; matches libwayland-client's struct wl_display *. */
struct wl_display;

typedef int (*wl_display_flush_fn) (struct wl_display *display);
typedef int (*wl_display_get_fd_fn) (struct wl_display *display);

static wl_display_flush_fn real_flush = NULL;
static wl_display_get_fd_fn real_get_fd = NULL;

static void
resolve_syms (void)
{
	if (real_flush == NULL)
		real_flush = (wl_display_flush_fn) dlsym (RTLD_NEXT, "wl_display_flush");
	if (real_get_fd == NULL)
		real_get_fd = (wl_display_get_fd_fn) dlsym (RTLD_NEXT, "wl_display_get_fd");
}

static int
env_int (const char *name, int fallback)
{
	const char *v = getenv (name);
	if (v == NULL || *v == '\0')
		return fallback;
	char *end = NULL;
	long n = strtol (v, &end, 10);
	if (end == v || n < 0 || n > 60000)
		return fallback;
	return (int) n;
}

static int64_t
now_ms (void)
{
	struct timespec ts;
	clock_gettime (CLOCK_MONOTONIC, &ts);
	return (int64_t) ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

int
wl_display_flush (struct wl_display *display)
{
	resolve_syms ();
	if (real_flush == NULL) {
		errno = ENOSYS;
		return -1;
	}

	int max_ms = env_int ("KDE_DOCKBAR_FLUSH_RETRY_MS", WL_FLUSH_RETRY_DEFAULT_MAX_MS);
	int slice_ms = env_int ("KDE_DOCKBAR_FLUSH_RETRY_SLICE_MS", WL_FLUSH_RETRY_DEFAULT_SLICE_MS);
	if (slice_ms < 1)
		slice_ms = 1;
	if (max_ms < slice_ms)
		max_ms = slice_ms;

	int64_t deadline = now_ms () + max_ms;
	int fd = -1;
	if (real_get_fd != NULL)
		fd = real_get_fd (display);

	for (;;) {
		int ret = real_flush (display);
		if (ret >= 0)
			return ret;

		int err = errno;
		if (err != EAGAIN && err != EWOULDBLOCK)
			return -1;

		int64_t left = deadline - now_ms ();
		if (left <= 0) {
			errno = EAGAIN;
			return -1;
		}

		int wait = slice_ms;
		if (wait > (int) left)
			wait = (int) left;

		if (fd >= 0) {
			struct pollfd pfd;
			pfd.fd = fd;
			pfd.events = POLLOUT;
			pfd.revents = 0;
			int pr = poll (&pfd, 1, wait);
			if (pr < 0) {
				if (errno == EINTR)
					continue;
			}
		} else {
			struct timespec req;
			req.tv_sec = wait / 1000;
			req.tv_nsec = (long) (wait % 1000) * 1000000L;
			nanosleep (&req, NULL);
		}
	}
}
