# Code Style Guidance

Prefer code whose purpose and flow are clear on the first read. Fewer lines are useful only when they make the code easier to understand.

## Clear Flow And Named Operations

- Separate choosing an operation from performing it. When dispatching by operation name, prefer one entry function with a short `case` that calls named operation functions
- Use separate function clauses when different data shapes make the implementation clearer, not automatically because this is Elixir
- Extract business logic into a named function when it represents a distinct operation, even if the function is short or used only once
- Do not extract a function merely to give a name to a guard, pattern match, trivial return tuple, config lookup, or standard-library call. Keep these expressions where the reader needs them
- Keep shared work, such as request logging when needed, at the entry point rather than repeating it across operations
- Prefer values that state their meaning: `to_timeout(hour: 1)` rather than `3_600_000`

For example, the reader can see the supported operations without reading their implementations:

```elixir
def handle(%{"method" => method}) do
  Logger.info("MCP: Handling #{method} request")

  case method do
    "server/discover" -> server_discover()
    "tools/list" -> tools_list()
    _ -> {:error, :method_not_found, "Method #{method} not found"}
  end
end
```

`server_discover/0` names an operation. A helper that only checks `is_map/1` and returns `:ok` does not. The goal is to make the business logic clear, not to put a function name around every expression.

## Validate At The Boundary

- Validate external input at the boundary, then let internal code rely on that contract
- Do not repeat guards or add catch-all invalid-argument clauses after validation
- When a contract guarantees a field exists, use direct access, `Map.fetch!`, or pattern matching rather than inventing fallback values
- Let broken internal or provider contracts fail clearly. Do not broadly rescue unexpected exceptions or replace them with vague errors
- Only return named errors when the caller can make a useful recovery or response decision; otherwise handle the error where enough context exists

## Build Only The Required Behavior

- Add optional paths and fallbacks only for a real product requirement or production safety need
- Avoid `maybe_*` branches when the domain expectation is definite
- Do not skip work because a field is already non-empty unless an explicit idempotency rule permits it
- Never substitute the current time for a missing or invalid timestamp unless the product accepts approximate time
- Do not preserve old props or data shapes merely because they used to exist

## Keep Responsibilities Clear

- Reuse existing application boundaries before adding provider-specific or flow-specific logic
- Share repeated behavior when it has one clear responsibility, such as finding or creating the same record across two flows
- Handlers coordinate operations; Services own writes and side effects; Finders own reads; Values shape output
- Controllers own transport concerns such as parameters, headers, status codes, and redirects
- Keep duplicate-write prevention near the write, not in every caller. Worker retries should be safe; use Oban uniqueness when duplicate execution is unsafe
- Callers should not inspect low-level changesets unless they own the write

## Configuration

- Keep provider URLs and defaults in config, not duplicated in modules
- Read secrets from the runtime environment; never fall back to checked-in secret placeholders
- Add provider defaults only after a real provider exists

## Naming

- Name modules and functions for the business operation or human action they represent, from the caller's point of view
- Use API terms only when they are also the relevant product or protocol concepts
- Avoid vague names such as `data`, `payload`, and `files` when a specific name exists
- If a name could fit ten unrelated places, it is too generic

For example, prefer `record_completion` over `process_data`, and `download_attachments` over `extract_from_files`.

## Errors And Logging

- Include useful identifiers in failure messages rather than logging only `not found`
- Preserve typed error reasons in logs and return values so failures remain searchable
- Worker failures should include enough context to decide whether to retry, discard, or fix the underlying problem
- Do not expose secrets or private user content in logs

## Specs And Docs

- Module docs should state what the module owns and which neighboring module owns the work it deliberately excludes
- Add docs or specs when they clarify behavior, side effects, or return contracts; skip boilerplate
- Put simple return contracts directly in specs. Introduce a named type only when it is reused or adds clarity
- No trailing periods in `@doc` and `@moduledoc` strings

## Tests

- Prefer tests through real application boundaries; do not mock internal application modules
- Mock external services with Mimic where available. Keep expectations visible in the test; support modules supply reusable responses, not hidden expectation setup
- Keep factories in `test/support/factory.ex` and non-factory helpers in `test/support/test_helpers.ex`
- For validation tests, start from factory attributes and override only the invalid field
- Give each test one distinct behavior and a name that makes its purpose clear
- Keep setup minimal and use expressive variable names instead of explanatory comments
- Do not add public production APIs or fake tools solely to make tests possible. Test the tool contract with the first real tool
- Check expected behavior against the underlying requirements, not just the implementation

## Before Finishing

- Can the reader see the operations and their order without reading every implementation?
- Does each extracted function own meaningful work, or merely hide an expression?
- Did I add a real behavior or an unnecessary fallback?
- Can failures be understood from their errors and logs?
- Have I addressed the reviewer's actual concerns rather than only the examples they gave?
