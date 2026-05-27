# dd-script-selector justfile

# List available recipes
default:
    @just --list

# Install deps and build assets
setup:
    mix setup

# Check builder API then start dev server at localhost:4000
dev: check-builder
    mix phx.server

# Start dev server with interactive shell
shell:
    iex -S mix phx.server

# Start dev server with a custom platform list (comma-separated)
dev-platforms platforms: check-builder
    PLATFORMS={{platforms}} mix phx.server

# Start dev server pointing at a custom builder API
dev-builder builder_base: (check-builder builder_base)
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

# Check if the builder API is reachable (fails loudly if not)
check-builder builder_base="http://localhost:8000":
    curl -sfo /dev/null {{builder_base}}/config?platform=example && echo "Builder API reachable" || (echo "Builder API unreachable — start dd-script-builder on {{builder_base}}" && exit 1)
