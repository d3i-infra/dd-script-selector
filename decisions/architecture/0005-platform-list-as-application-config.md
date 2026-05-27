# ADR 0005 — Platform list as application config

**Status:** Accepted. Source: conversation.

## Decision

The set of supported platforms is not stored in a database.
It is a static list in application config (`:dd_script_selector,
:platforms`), overridden at runtime by the `PLATFORMS` env var
(comma-separated). The default production list is:
`chatgpt chrome facebook instagram linkedin netflix tiktok
whatsapp x youtube`.

## Implication

- There is no admin UI or database migration needed to add or
  remove platforms; it is an operational change (env var or
  config redeploy).
- `Platforms.list/0` iterates this list, calls the builder API
  for each entry, and silently drops any that fail — the list
  is authoritative but the builder is the source of truth for
  each platform's schema.
