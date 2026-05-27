# ADR 0007 — Iframe-embeddable UI

**Status:** Accepted. Source: commit `f10efda`.

## Decision

The application is intended to be embedded inside an iframe
on external pages. The `:browser` pipeline explicitly deletes
the `x-frame-options` and `content-security-policy` response
headers via the `configure_framing_headers` plug, overriding
Phoenix's secure defaults.

## Implication

- Clickjacking protection is intentionally absent; this is
  accepted because the app exposes no authenticated user data
  and performs no state-mutating actions on behalf of a logged-in
  user.
- If authentication or sensitive operations are added in the
  future, framing headers must be reinstated and this ADR
  superseded.
