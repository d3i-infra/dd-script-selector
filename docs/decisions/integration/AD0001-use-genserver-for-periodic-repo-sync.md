# AD0001: Use a GenServer with `git clone` for Periodic Repository Sync

**Status:** Accepted  
**Date:** 2026-04-08

## Context and Problem Statement

The application needs a local, up-to-date copy of the `data-donation-task` GitHub repository so it can inspect its Python scripts. We need to decide how to obtain and refresh that copy.

## Options Evaluated

1. **GenServer + `System.cmd("git", ["clone", ...])`** — an OTP process that runs on startup and every 24 hours, performing a fresh `git clone` into `repos/`
2. **HTTP API (GitHub REST / GraphQL)** — fetch file contents on demand via the GitHub API using `Req`
3. **`git pull` on an existing clone** — keep a persistent clone and pull updates instead of re-cloning

## Decision

Use a supervised GenServer (`DdScriptSelector.RepoSyncer`) that removes any existing clone and re-clones the repository every 24 hours via `System.cmd/3`.

## Benefits

- Simple and self-contained: standard OTP pattern, no external HTTP dependency for file access
- Full local copy means all file operations (listing, reading) are cheap filesystem calls
- Re-cloning always yields a clean state; no risk of dirty working-tree or merge conflicts
- Configurable via application environment (`repo_url`, `target_dir`)

## Drawbacks

- Requires `git` to be available on the host
- A full clone is heavier than fetching individual files via API, especially as the repo grows
- 24-hour refresh window means scripts added to the repo can be stale by up to a day

## Consequences

- `repos/` is excluded from version control via `.gitignore`
- The GenServer is started as a supervised child in `DdScriptSelector.Application`
- Tests can inject a custom `target_dir` and `repo_url` via application config to avoid real network calls
