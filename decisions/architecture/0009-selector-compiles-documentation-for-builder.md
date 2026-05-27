# ADR 0009 — Selector compiles documentation sent to the builder

**Status:** Accepted. Source: conversation.

## Decision

The selector (this app) is responsible for assembling and
compiling all documentation that is sent to the builder. Before
calling the builder API, the selector gathers the relevant
script docstrings and any other contextual information, formats
them into the payload, and passes the result to the builder.
The builder receives ready-to-use documentation; it does not
fetch or assemble it independently.

## Implication

Documentation compilation logic belongs in the selector's
business layer (`lib/dd_script_selector/`), not in the builder
integration module. Any change to what documentation is
included or how it is formatted is made here, not in the
builder service.

The module responsible is `DdScriptSelector.DocumentationFormatter`
(`lib/dd_script_selector/documentation_formatter.ex`). It takes
the selected tables (with their enabled headers) and platform info,
and returns a markdown string that is sent to the builder.
