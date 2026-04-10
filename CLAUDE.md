# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

A Phoenix LiveView app for browsing and selecting data-donation task scripts. It reads Python platform scripts from a configured directory, extracts their docstrings, and lets users pick a script via a web UI.

Key LiveViews: `HomeLive` (`/`), `ScriptSelectorLive` (`/select`)
Key business modules: `DdScriptSelector.Platforms` (lists platform scripts), `DdScriptSelector.PyDocExtractor` (parses Python docstrings)

## Commands

```bash
mix setup                        # Install deps, create/migrate DB, build assets
mix phx.server                   # Start dev server at localhost:4000
iex -S mix phx.server            # Start with interactive shell

mix test                         # Run all tests (creates/migrates test DB automatically)
mix test test/path/to_test.exs   # Run a single test file
mix test --failed                # Re-run only previously failed tests

mix precommit                    # Pre-commit check: compile (warnings as errors), unlock unused deps, format, test
mix ecto.reset                   # Drop and recreate database
mix ecto.gen.migration name      # Generate a migration (always use this, never create manually)
```

## Architecture

Standard Phoenix 1.8 umbrella-style layout with two logical layers:

- `lib/dd_script_selector/` — business logic (contexts, schemas, Repo, Mailer)
- `lib/dd_script_selector_web/` — web layer (router, controllers, LiveViews, components)

Key web files:
- `router.ex` — all routes; `:browser` pipeline wraps HTML routes
- `components/core_components.ex` — shared UI components (`<.input>`, `<.icon>`, etc.), imported everywhere
- `components/layouts.ex` — `<Layouts.app>` wraps all LiveView content; contains `<.flash_group>`
- `dd_script_selector_web.ex` — defines `use DdScriptSelectorWeb, :live_view` etc.; add global aliases/imports to `html_helpers/0`

Assets:
- `assets/js/app.js` and `assets/css/app.css` are the only supported bundles — vendor deps must be imported here
- Tailwind v4 uses `@import "tailwindcss" source(none)` syntax — no `tailwind.config.js`

## Key Guidelines

### HTTP
Use `Req` for HTTP requests. Do **not** use `:httpoison`, `:tesla`, or `:httpc`.

### LiveView
- Wrap all LiveView templates with `<Layouts.app flash={@flash} ...>` — `MyAppWeb.Layouts` is already aliased
- Use `push_navigate`/`push_patch` in LiveView modules; use `<.link navigate={}>` / `<.link patch={}>` in templates
- Use LiveView streams (`stream/3`, `stream_insert/3`, `stream_delete/3`) for all collections — never assign plain lists
- Streams are not enumerable; to filter, refetch data and `stream(..., reset: true)`
- When an assign change should affect a streamed item's rendered output, `stream_insert` the item again
- Colocated JS hooks use `:type={Phoenix.LiveView.ColocatedHook}` and names **must** start with `.`
- Never write raw `<script>` tags in HEEx; never use `phx-update="append"` / `"prepend"`

### Forms
- Always use `to_form/2` in the LiveView and `<.form for={@form}>` in the template
- Never pass a changeset directly to `<.form>` or access `@changeset` in templates
- Use `<.input field={@form[:field]}>` from `core_components.ex`

### Ecto
- Always preload associations in queries before accessing them in templates
- Use `Ecto.Changeset.get_field/2` to read changeset fields — never `changeset[:field]`

### Elixir gotchas
- Lists don't support index access (`list[i]` is invalid) — use `Enum.at/2`
- `if/else if` doesn't exist — use `cond` or `case` for multiple branches
- Block expressions (`if`, `case`) must have their result rebound: `socket = if ... do ... end`
- Never nest multiple modules in the same file
- Never use `map[:field]` access on structs — use `struct.field` or `Ecto.Changeset.get_field/2`
- Fields set programmatically (e.g. `user_id`) must not appear in `cast/3`

### HEEx templates
- Use `{@assign}` for interpolation in tag bodies and attributes; use `<%= %>` only for block constructs
- Use `[...]` list syntax for conditional classes: `class={["base-class", @flag && "extra-class"]}`
- HTML comments: `<%!-- comment --%>`
- For literal `{` / `}` in code blocks, annotate the parent tag with `phx-no-curly-interpolation`

### Testing
- Use `start_supervised!/1` for processes; avoid `Process.sleep/1`
- To wait for a process to finish, use `Process.monitor/1` + `assert_receive {:DOWN, ^ref, :process, ^pid, :normal}` — not sleep
- Use `has_element?/2` and `element/2` from `Phoenix.LiveViewTest` — never test raw HTML strings
- `LazyHTML` (included) is available for selector-based HTML inspection in tests
