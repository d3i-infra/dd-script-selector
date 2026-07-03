# ADR 0003 — Builder API as external service

**Status:** Accepted. Source: conversation.

## Decision

All platform configuration retrieval and script building is
delegated to an external dd-script-builder HTTP service.
`PyDocExtractor` fetches platform config via
`GET <builder_base>/config?platform=<name>`.
`ScriptSelectorLive` triggers builds via `POST <builder_base>/build`
and polls `GET <builder_base>/status/:id`.
`BuildController` proxies file downloads from
`GET <builder_base>/download/:id` and cleans up the build afterwards
via `DELETE <builder_base>/build/:id`.

The builder base URL is configured via `:builder_base` app env
(`BUILDER_BASE` env var in production; default `http://localhost:8000`).

## Implication

- This app contains no Python execution or script-building logic.
- All HTTP calls to the builder use `Req`; no other HTTP client is used.
- If the builder is unavailable, `Platforms.list/0` silently drops
  the failing platform and `emit_config` returns a build error to the UI.
- Changing the builder contract (endpoints, payload shape) requires
  coordinated changes in `PyDocExtractor`, `ScriptSelectorLive`, and
  `BuildController`.
