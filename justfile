# dd-script-selector justfile

# List available recipes
default:
    @just --list

# Install deps and build assets
setup:
    mix setup

# Start dev server at localhost:4000
dev:
    mix phx.server

# Start dev server with interactive shell
shell:
    iex -S mix phx.server

# Start dev server with a custom platform list (comma-separated)
dev-platforms platforms:
    PLATFORMS={{platforms}} mix phx.server

# Start dev server pointing at a custom builder API
dev-builder builder_base:
    BUILDER_BASE={{builder_base}} mix phx.server

# Run all tests
test:
    mix test

# Run a single test file
test-file file:
    mix test {{file}}

# Re-run only previously failed tests
test-failed:
    mix test --failed

# Pre-commit check: compile, format, test
precommit:
    mix precommit

# Format code
fmt:
    mix format
