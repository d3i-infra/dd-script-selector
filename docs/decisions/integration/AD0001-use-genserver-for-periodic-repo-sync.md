# AD0001: Use a GenServer with `git clone` and `pnpm install` for Periodic Repository Sync

**Status:** Accepted  
**Date:** 2026-04-08

## Context and Problem Statement

The application needs a local, up-to-date copy of the `data-donation-task` GitHub repository so it can inspect its Python scripts. The repository is a pnpm project containing JavaScript build tools; after cloning, its dependencies must be installed before those tools can be used. We need to decide how to obtain, refresh, and prepare that copy.

## Options Evaluated

1. **GenServer + `System.cmd("git", ["clone", ...])` + `pnpm install`** — an OTP process that runs on startup and every 24 hours, performing a fresh `git clone` followed by `pnpm install --frozen-lockfile`
2. **HTTP API (GitHub REST / GraphQL)** — fetch file contents on demand via the GitHub API using `Req`
3. **`git pull` on an existing clone** — keep a persistent clone and pull updates instead of re-cloning

## Decision

Use a supervised GenServer (`DdScriptSelector.RepoSyncer`) that removes any existing clone, re-clones the repository every 24 hours via `System.cmd/3`, and then runs `pnpm install --frozen-lockfile` in the cloned directory to install dependencies.

The module is intentionally specific to the `data-donation-task` repository; the URL and local target directory are hardcoded and not configurable at runtime.

## Benefits

- Simple and self-contained: standard OTP pattern, no external HTTP dependency for file access
- Full local copy means all file operations (listing, reading) are cheap filesystem calls
- Re-cloning always yields a clean state; no risk of dirty working-tree or merge conflicts
- Running `pnpm install --frozen-lockfile` after each clone ensures the build tools are ready to use and that the exact dependency versions from the lockfile are respected

## Drawbacks

- Requires `git`, `pnpm`, and `poetry` to be available on the host
- A full clone is heavier than fetching individual files via API, especially as the repo grows
- 24-hour refresh window means scripts added to the repo can be stale by up to a day
- `pnpm install` adds time to each sync cycle

## Consequences

- The data-donation-task repo is downloaded in the System.temp() folder 
- The GenServer is started as a supervised child in `DdScriptSelector.Application`
- After each successful clone, `pnpm install --frozen-lockfile` is run in the cloned directory; a failure at either step is logged and the error is returned
- Tests exercise the clone step via `sync/2`, which accepts explicit URL and target directory arguments
