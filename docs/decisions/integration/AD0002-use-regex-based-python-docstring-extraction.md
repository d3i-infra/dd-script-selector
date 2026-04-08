# AD0002: Use Pure-Elixir Regex Parsing for Python Docstring Extraction

**Status:** Accepted  
**Date:** 2026-04-08

## Context and Problem Statement

The application needs to extract module-level and function-level docstrings from Python source files in the synced repository so it can display script metadata to users. We need to decide how to parse the Python files.

## Options Evaluated

1. **Pure-Elixir regex parsing** — use `Regex.scan/2` and `Regex.run/2` in an Elixir module to match `def` blocks and triple-quoted docstrings
2. **Spawn a Python subprocess** — call `python3 -c "import ast; ..."` via `System.cmd/3` to use Python's own `ast` module
3. **External parsing service** — send source to an HTTP endpoint that performs AST-based extraction

## Decision

Use a pure-Elixir regex-based approach (`DdScriptSelector.PyDocExtractor`). The extractor matches top-level `def` statements and immediately-following triple-quoted strings without leaving the BEAM.

## Benefits

- No runtime dependency on Python or any external service
- Fast and synchronous: a single `File.read/1` plus a few regex passes
- Fully testable in standard ExUnit with inline fixture strings

## Drawbacks

- Regex cannot handle all valid Python syntax (e.g. multi-line function signatures, nested functions with the same name, decorators that span lines)
- Only top-level `def` blocks are matched; methods inside classes are not extracted

## Consequences

- `PyDocExtractor` is limited to the subset of Python files that follow conventional formatting (top-level functions, standard triple-quote docstrings)
- If more accurate parsing is needed in future, the module interface (`extract/1`, `parse/1`) is narrow enough to swap the implementation for an AST-based approach without changing callers
