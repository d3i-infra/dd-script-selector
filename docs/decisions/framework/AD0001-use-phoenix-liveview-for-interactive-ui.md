# AD0001: Use Phoenix LiveView as the Primary UI Framework

**Status:** Accepted  
**Date:** 2026-04-07

## Context and Problem Statement

`dd-script-selector` is a web application that needs interactive UI — users select and configure scripts. We need to decide on the approach for delivering that interactivity.

## Options Evaluated

1. **Phoenix LiveView** — server-rendered reactive UI over WebSockets, no separate JS framework needed
2. **Phoenix + React/Vue SPA** — Phoenix as API backend, separate JS frontend
3. **Plain Phoenix controllers + forms** — traditional request/response, no real-time updates

## Decision

Use Phoenix LiveView (Phoenix 1.8, LiveView 1.1). The application is scaffolded with `phx.new` and LiveView is the default interaction model.

## Benefits

- Full-stack Elixir: business logic and UI share the same process model and data structures
- No separate API layer or client-side state management
- LiveView streams handle large collections efficiently without memory ballooning
- Built-in support for real-time updates if needed later

## Drawbacks

- Requires a persistent WebSocket connection per user session
- Complex client-side interactions (drag-and-drop, rich editors) require JS hooks via `phx-hook`

## Consequences

- All interactive pages are implemented as LiveViews under `lib/dd_script_selector_web/`
- Templates use HEEx (`.html.heex`) or the `~H` sigil
- Client-side JavaScript is limited to `assets/js/app.js`; colocated hooks use `:type={Phoenix.LiveView.ColocatedHook}` with a `.Name` prefix
