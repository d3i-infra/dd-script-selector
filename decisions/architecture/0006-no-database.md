# ADR 0006 — No database

**Status:** Accepted. Source: conversation.

## Decision

This application has no database and no Ecto Repo. All
runtime state is either held in-process (PlatformsCache
GenServer, LiveView socket assigns) or delegated to the
external builder service. There are no schemas, migrations,
or persistence concerns in this codebase.

## Implication

- Do not add Ecto, a Repo, or any database dependency.
- Session state that must survive a LiveView reconnect must
  be re-fetched from the builder API or re-derived from
  URL params; it cannot be read from a database.
- If persistence is needed in the future, this ADR must be
  superseded and a migration strategy decided.
