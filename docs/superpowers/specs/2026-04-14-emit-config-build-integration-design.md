# Emit Config → Build Integration Design

**Date:** 2026-04-14  
**Status:** Approved

## Overview

When the user clicks "Emit config" in `ScriptSelectorLive`, the app POSTs the selected configuration to the `dd-script-builder` API, polls for build status, streams live logs to the UI, and automatically downloads the resulting zip through Phoenix when the build completes. The user never communicates directly with the builder API — all traffic is proxied through the Phoenix server.

## Architecture & Data Flow

```
User clicks "Emit config"
  → LiveView handle_event("emit_config")
  → Req.post("http://localhost:8000/build", json: %{
        config: <json string>,
        config_path: "port_config.json",
        output_dir: "releases"
      })
  → assigns: build_id, build_status: "queued", build_logs: []
  → Process.send_after(self(), :poll_build, 2_000)

handle_info(:poll_build, socket)
  → Req.get("http://localhost:8000/status/{build_id}")
  → update assigns: build_status, build_logs
  → "queued" | "running" → reschedule in 2s
  → "done"  → push_event("trigger-download-url", %{path: "/builds/{id}/download"})
  → "error" → stop polling, show error, re-enable button

JS handler for "phx:trigger-download-url"
  → creates <a href="/builds/{id}/download" download> and clicks it

Phoenix BuildController  GET /builds/:id/download
  → Req.get!("http://localhost:8000/download/{id}", into: :self)
  → streams zip to browser as attachment "build.zip"
```

## Builder API (dd-script-builder, localhost:8000)

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/build` | Start a build, returns `{build_id}` |
| GET | `/status/:id` | Poll status: `queued`, `running`, `done`, `error` + `logs` list |
| GET | `/download/:id` | Download zip (only when `done`) |
| DELETE | `/build/:id` | Cleanup (not used in this feature) |

Build request body:
```json
{
  "config": "<json string of selected tables config>",
  "config_path": "port_config.json",
  "output_dir": "releases"
}
```

## New LiveView Assigns

```elixir
:build_id      # nil | UUID string
:build_status  # nil | "queued" | "running" | "done" | "error"
:build_logs    # [] | list of strings
:build_error   # nil | string
```

## UI Behaviour

The bottom action bar of the configure step is the primary surface for all build feedback. The "Emit config" button transforms in-place based on state — no separate panels, no page navigation.

### Idle (no build running)
- "Emit config" button is active (if config is valid) or disabled (if invalid).

### Building (queued / running)
- "Emit config" button is replaced by a spinner + "Building…" label; the button is non-interactive.
- A scrollable log panel appears above the action bar, showing live log lines as they arrive. Logs auto-scroll to the bottom.
- The back button is also disabled to prevent navigation during a build.

### Done
- Log panel shows final log lines.
- A green success banner appears: "Build complete — downloading…"
- Download triggers automatically. No user action required.
- After a short delay (2s), the success banner fades and the button resets to "Emit config" so the user can re-run if needed.

### Error
- Log panel stays visible so the user can see what went wrong.
- A red error banner shows the error message.
- The "Emit config" button re-enables immediately — clicking it starts a fresh build (new build_id, clears old logs).

## New Files & Changes

### New files
- `lib/dd_script_selector_web/controllers/build_controller.ex` — proxies the zip download
- `lib/dd_script_selector_web/controllers/build_html.ex` — (if needed for error views; likely not)

### Modified files
- `lib/dd_script_selector_web/router.ex` — add `GET /builds/:id/download`
- `lib/dd_script_selector_web/live/script_selector_live.ex` — polling logic, new assigns, updated `emit_config` handler
- `lib/dd_script_selector_web/live/script_selector_live.html.heex` — build status UI
- `assets/js/app.js` — add `phx:trigger-download-url` handler (distinct from existing base64 `phx:trigger-download`)

## Error Handling

- If `POST /build` fails (builder API down): set `build_status: "error"`, `build_error: "Builder API unavailable"`.
- If a poll returns a non-200: treat as transient, retry up to 3 times before marking error.
- If `build_status` is `"error"` from the API: display `result["error"]` in the UI.
- No automatic retry — user decides whether to re-submit.

## Testing

- Unit test `build_config/1` output shape matches builder API expectations.
- LiveView test: mock the builder API with `Req.Test`, assert assigns transition correctly through `queued → running → done`.
- LiveView test: assert error state re-enables the button.
- Controller test: assert `/builds/:id/download` proxies the response with correct content-disposition header.
