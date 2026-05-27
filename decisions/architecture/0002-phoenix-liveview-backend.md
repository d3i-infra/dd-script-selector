# ADR 0002 — Phoenix LiveView backend

**Status:** Accepted. Source: conversation.

## Decision

The server is an Elixir/Phoenix 1.8 application using Phoenix
LiveView for all user-facing UI. Bandit is the HTTP adapter.
There is no separate frontend framework; all interactivity is
handled via LiveView socket assigns and events.

## Implication

- All UI pages are LiveViews; no SPA or separate JS framework.
- New interactive pages are implemented as LiveView modules
  under `lib/dd_script_selector_web/live/`.
- Server-side state lives in socket assigns; client-side state
  is limited to what LiveView JS hooks require.
