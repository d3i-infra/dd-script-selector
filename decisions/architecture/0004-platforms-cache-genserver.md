# ADR 0004 — Platforms cache GenServer

**Status:** Accepted. Source: conversation.

## Decision

Platform data (fetched from the builder API) is cached in a
named GenServer (`PlatformsCache`) that loads at application
startup and refreshes every 24 hours via `Process.send_after`.
LiveViews call `PlatformsCache.list/0` rather than hitting the
builder API per request.

## Implication

- On startup, if the builder API is unreachable, `PlatformsCache`
  starts with an empty list; the UI shows no platforms until the
  next refresh or a restart.
- There is no on-demand cache invalidation; changes to platform
  scripts on the builder side take up to 24 hours to propagate,
  or require a process restart.
- `PlatformsCache` is registered under its module name; tests
  that exercise it must account for the named process already
  running.
