# Code Style Guidance

This document captures durable code review preferences for this template.

The pattern is clear: prefer less defensive/duplicative code, stronger ownership boundaries, and clearer data contracts.

## Rules For Future Code

- Do not duplicate config in code
- Provider base URLs/defaults belong in config, not module constants, unless there is a clear reason
- Secrets, API keys, and webhook secrets come from env at runtime, not checked-in config values
- Runtime config should not fall back to checked-in secret placeholders
- Add provider defaults to config only after a real provider exists

## Simplicity First

- Prefer the smallest code that clearly expresses the real product path
- Do not add helpers just to name one standard-library call, one config read, or one branch
- Do not add defensive checks for internal contracts that were already established at the boundary
- Do not add fallback branches for states the product does not intentionally support
- Do not normalize every possible provider failure into app-specific errors; handle only failures the caller can recover from or display usefully
- Let broken provider response shapes, missing required fields, and impossible internal states fail loudly instead of hiding them behind vague errors
- Assume code works after the boundary validates the inputs; repeated checks muddy clarity and violate this project’s style
- Keep optionality out of the code unless the product truly has an optional path
- If a function exists only because code felt too long, inline it unless it owns real behavior or a reusable boundary
- More code is worse when it does not buy current product behavior, clearer intent, or a useful recovery path

## Reuse Existing Boundaries

- Reuse existing boundaries before adding provider-specific or flow-specific logic
- Before adding a provider-specific helper, check if another provider or app boundary already does the same thing
- If two providers normalize HTTP errors the same way, create a shared provider helper
- If two flows find-or-create the same record the same way, make it a focused service
- If test setup repeats provider stubs or payloads, move it to `test/support` or factories

## Keep Orchestration Thin

- Processor and handler modules should coordinate steps, not own low-level storage, dedupe, lookup, or changeset inspection
- Domain lookup/create behavior belongs in focused services or finders
- Dedupe behavior belongs near the write that can duplicate, not every caller
- Controllers should stay focused on transport concerns: params, redirects, flash, status, and Inertia props
- Response/prop shaping that grows beyond a small local map belongs in a Value module

## Avoid Maybe Code

- Avoid `maybe_*` branches when the domain expectation is definite
- Do not skip work because an existing field happens to be non-empty unless the idempotency rule is explicit
- Do not add fallback paths unless there is a real product requirement or production safety need
- Prefer one clear implementation path in active work

## Do Not Invent Fallback Data

- If an external or internal contract says data exists, fetch it directly and fail clearly if absent
- Prefer `Map.fetch!`, precise pattern matching, or explicit `with` branches over silent fallback logic when missing data means a broken contract
- Do not fall back from missing/invalid timestamps to `DateTime.utc_now` unless the product explicitly accepts approximate time
- Do not preserve old prop fields or data shapes just because they used to exist

## Fail Loudly Enough To Debug

- Not-found cases should log useful identifiers
- A log like `not found` is insufficient; include the id needed to find the failing event, user-visible resource, organization, provider object, or job
- Worker failures should preserve enough context to decide whether to wait, retry, discard, or fix data
- Preserve typed reason atoms in logs and return values so failures stay searchable and testable
- Only bubble named errors when a caller can make a specific recovery or response decision from that name; otherwise handle the error at the boundary that has enough context
- Do not broadly rescue unexpected exceptions inside internal code; let them crash where supervisors, Oban, or tests can expose the real failure

## Specs And Docs

- Keep specs simple
- Do not introduce a named `@type` for a one-off return shape unless it is reused or improves clarity
- Put simple return contracts directly in the `@spec`
- Add `@doc` or `@moduledoc` only when it clarifies caller-facing behavior, side effects, or non-obvious boundaries
- No trailing periods in `@doc` and `@moduledoc` strings

## Remove Defensive Noise

- Remove unnecessary guards and defensive clauses
- Avoid `when is_binary(id) and byte_size(id) > 0` if the caller/provider contract already owns validity
- Avoid catch-all invalid argument clauses unless they are part of a real public boundary
- Let bad internal data fail obviously instead of being quietly translated into vague discard reasons

## Naming Rules

Names must explain the job to a human reading the call site.

- Name things for the domain decision or human action they represent, not for the API mechanism, data shape, or implementation detail underneath
- A caller should understand why the function/module exists without opening it
- Avoid API jargon unless the API concept is also the product/domain concept
- Avoid vague bucket names like `input`, `payload`, `data`, `attachments`, `source`, or `files` when the thing has a more specific role
- Helper names should say the work being done
- Module names should describe the function/use so a human can understand the intent from the name
- Client methods should be named from the caller's perspective, not the provider endpoint
- Prefer plain names when there is only one obvious thing in scope
- If a name could fit ten unrelated modules, it is too generic

## Naming Check

Before keeping a new module, function, variable, or helper name, ask:

- Does this name say what job this code does?
- Is it named from the caller's point of view?
- Is it named after provider/API mechanics instead of app behavior?
- Could this name fit ten unrelated modules?

## Naming Examples

Bad:

- `input_file_completion`
- `structured_response_with_files`
- `extract_from_files`
- `BuildSourceInput`
- `source_attrs`
- `attachments`
- `payload`
- `data`

Better:

- `ask`
- `ask_with_files`
- `BuildPromptBySource`
- `source_relationship_attrs`
- `download_attachments`
- `stored_attachment_name`

## Helpers

- A private helper is worth keeping only if it owns meaningful behavior
- Inline helpers that only wrap one standard-library call
- Private helpers that exist to hide uncertain or defensive branching are usually a smell
- Avoid broad private-helper extraction; rely heavily on the standard library
- If a one-line helper only renames a standard-library call, delete it and inline the call

## Tests

- Put reusable factories in `test/support/factory.ex`
- Put non-factory helpers in `test/support/test_helpers.ex`
- Mock external service boundaries with Mimic when needed
- Do not mock internal domain/application modules in integration tests
- Keep external-boundary expectations visible in the test
- Reusable support modules should provide return values/responses, not hide `Mimic.expect(...)` setup
- Start from `params_for(...)` for validation tests and override only the invalid field under test
- Test names should describe the behavior that failed
- Each test should verify one distinct behavior, though it may have many assertions
- Keep setup and mocking minimal and obvious
- Do not add public production APIs only to make tests easier; prefer dependency injection at existing boundaries

## Idempotency

- Put idempotency at the correct boundary
- Worker reruns should be safe
- Unique/duplicate handling should live near the write that can duplicate
- Callers should not inspect low-level changesets unless they are the service responsible for that write
- Use Oban uniqueness when duplicate execution would be unsafe

## Short Checklist

- Did I check for existing code before adding a new provider-specific helper?
- Is this module orchestrating, or is it secretly doing storage/query/dedupe work?
- Am I using config/env instead of hardcoded provider settings?
- Am I adding fallback behavior because the domain needs it, or because I am being defensive?
- If the provider or internal contract is broken, will this fail clearly?
- If something is not found, will logs include the id needed to debug it?
- Are test stubs/factories centralized?
- Did I reply to every review comment after changing or answering it?
