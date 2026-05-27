# ADR 0008 — Build polling in LiveView

**Status:** Accepted. Source: conversation.

## Decision

After submitting a build request to the builder API,
`ScriptSelectorLive` polls for build status using
`Process.send_after(self(), :poll_build, 2_000)` and handles
the response in `handle_info/2`. The process retries up to 3
times on network error before surfacing a failure. On success
("done"), it emits a `trigger-download-url` JS event so the
browser initiates the file download, then resets build state
after 2 seconds.

## Implication

- Build status is transient LiveView state; a page refresh
  loses the build_id and the in-progress indication, though
  the actual build on the builder side may still complete.
- The poll interval is fixed at 2 seconds; do not introduce
  exponential backoff or configurable intervals without
  superseding this ADR.
- The download is triggered by a client-side JS event
  (`trigger-download-url`); the corresponding hook must remain
  registered in `app.js`.
