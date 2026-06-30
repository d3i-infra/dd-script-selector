# ADR 0004 — Platforms cache GenServer

**Status:** Accepted. Source: conversation.

## Decision

Platform data (fetched from the builder API) is cached in a
named GenServer (`PlatformsCache`) that loads at application
startup and refreshes every 24 hours via `Process.send_after`.
LiveViews call `PlatformsCache.list/0` rather than hitting the
builder API per request.

## Amendments

### Non-blocking startup with background Task (2026-06-30)

`init/1` now returns immediately with an error state. A `Task` is
spawned to load platforms in the background and casts the result
back to the GenServer. This prevents the supervision tree from
blocking while HTTP requests to the builder API are in flight.

### Error state and retry on partial load (2026-06-30)

`list/0` returns `{:ok, platforms}` or `{:error, :init_failed}`.
The cache is only considered healthy (`:ok`) when **all** configured
platforms have loaded successfully — a partial result (one or more
platforms failing to extract) is treated as an error.

On error the cache retries every **1 minute** (`@retry_interval`)
instead of waiting 24 hours. The 24-hour refresh interval is only
scheduled after a fully successful load.

### PubSub notification on successful load (2026-06-30)

When platforms transition from error to ok the GenServer broadcasts
`:platforms_available` on the `"platforms_cache"` PubSub topic.
`ScriptSelectorLive` subscribes on connect and updates its assigns
immediately when notified, so the error banner disappears and the
platform list appears without a page reload or manual retry.

## Implication

- On startup the UI immediately shows an error banner if platforms
  are not yet loaded or if any platform failed; the banner clears
  automatically once all platforms are available.
- There is no on-demand cache invalidation; changes to platform
  scripts on the builder side take up to 24 hours to propagate,
  or require a process restart.
- `PlatformsCache` is registered under its module name; tests
  that exercise it must account for the named process already
  running.
