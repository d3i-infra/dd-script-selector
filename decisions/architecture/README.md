# Architectural decisions

This directory holds the project's Architectural Decision
Records (ADRs). The framework and conventions are defined in
[`0001-adr-framework-and-conventions.md`](./0001-adr-framework-and-conventions.md);
read it first.

## Index

### Meta

- [0001 — ADR framework and conventions](./0001-adr-framework-and-conventions.md)

### Application shape

- [0002 — Phoenix LiveView backend](./0002-phoenix-liveview-backend.md)
- [0006 — No database](./0006-no-database.md)
- [0007 — Iframe-embeddable UI](./0007-iframe-embeddable.md)

### External integrations

- [0003 — Builder API as external service](./0003-builder-api-external-service.md)

### Data and caching

- [0004 — Platforms cache GenServer](./0004-platforms-cache-genserver.md)
- [0005 — Platform list as application config](./0005-platform-list-as-application-config.md)

### Build workflow

- [0008 — Build polling in LiveView](./0008-build-polling-in-liveview.md)

## How to use this directory

When working on code in this repo, load the ADR(s) whose
filenames match the area you are touching. The four-digit
prefix is for ordering and stable reference; the slug is for
topic-recognition. For example, before changing how platforms
are fetched or cached, load `0004-platforms-cache-genserver.md`
and `0003-builder-api-external-service.md`.

When a decision surfaces in conversation that warrants an
ADR but does not yet have one, prompt the user to escalate.
Do not silently encode a decision into code without an ADR
to back it.
