# AD0001: Use MADR for Architectural Decision Records

**Status:** Accepted  
**Date:** 2026-04-07

## Context and Problem Statement

Architectural decisions made during development are often undocumented, leaving future contributors without context for why things are the way they are. We need a lightweight, structured way to record significant decisions.

## Options Evaluated

1. **MADR (Markdown Architectural Decision Records)** — structured Markdown files, stored in the repo, with a defined template
2. **No formal process** — decisions recorded ad hoc in commit messages or pull requests

## Decision

Use MADR stored under `docs/decisions/`, organized into thematic subdirectories per domain (e.g. `framework/`, `governance/`). Each subdirectory has an `index.yaml` tracking status, tags, and relationships between decisions.

ADRs are named `AD[NNNN]-kebab-case-title.md`, with IDs scoped per subdirectory.

## Benefits

- Decisions live in the repo alongside the code they describe
- Lightweight enough that writing one takes minutes, not hours
- The `index.yaml` enables status tracking and dependency relationships without extra tooling

## Drawbacks

- Requires discipline to write ADRs at decision time rather than retroactively
- Index files must be kept in sync manually

## Consequences

All significant architectural or process decisions should be recorded as ADRs in the appropriate subdirectory. If no suitable subdirectory exists, create one.
