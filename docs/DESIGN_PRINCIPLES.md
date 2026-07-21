# Design Principles

This document is both values and operating guidance.
Values define how we think. Rules define how agents execute when details are missing.

## Values

- Build in small, complete iterations (vertical slices), not partial architecture.
- Prefer simple, sufficient solutions now; avoid speculative complexity.
- Defer intentionally: do not build for hypothetical future needs before they are real.
- Make tradeoffs explicit and visible instead of hiding uncertainty behind false certainty.
- Enforce scope discipline with clear boundaries for what is in vs out of the current iteration.
- Optimize for learning velocity: each increment should validate assumptions and reduce risk.

## Core Principles

- **KISS** - Keep it simple. Complexity is a cost, not a feature.
- **YAGNI** - Do not build it until there is a real need.
- **Rule of Three (DRY)** - Duplication is acceptable until the third clear occurrence. Then refactor unless the abstraction reduces clarity.
- **Let It Crash** - Use BEAM supervision and process boundaries instead of defensive over-handling.
- **Principle of Least Astonishment** - Code should do what a reader expects.
- **Favor Immutability** - Prefer immutable data and explicit transformations.
- **Separation of Concerns** - Keep concerns distinct without introducing indirection for its own sake.
- **Prefer Explicit Over Hidden** - Internal clarity beats unnecessary encapsulation. Reserve strict information hiding for public API boundaries.

## Decision Order (When Principles Conflict)

Use this order to resolve tradeoffs:

1. Ship a working, testable vertical slice.
2. Keep the solution simple and readable.
3. Avoid speculative abstractions and defer future-facing work.
4. Make tradeoffs and uncertainty explicit.
5. Refactor only when repetition or complexity justifies it.

If a choice improves one rule while harming a higher-priority rule, prefer the higher-priority rule.

## Operating Rules for Agents

### Definition of "Complete Slice"

A slice is complete when it includes all of the following:

- A user-visible or externally observable behavior works end-to-end.
- Core tests cover the happy path and the most likely failure path.
- Logging/telemetry is sufficient to debug the new path.
- Any schema/data change has a safe migration and rollback plan.
- Scope boundaries are documented: what is included now vs deferred.

### Default Behavior Under Uncertainty

- Prefer the smallest change that can be validated quickly.
- If multiple valid options exist, choose the least complex one that preserves future extension.
- Prefer one clear implementation path in active work; avoid fallback/parallel paths unless they are required for production safety.
- Ask for human input only when the choice materially changes architecture, security posture, data integrity, or irreversible behavior.
- Do not hide uncertainty. Record assumptions and why a choice was made.

### "Let It Crash" Boundaries

- Let processes fail at process boundaries where supervisors can recover.
- Do not expose raw crashes to end users when graceful error handling is expected.
- Favor explicit error contracts at API and UX boundaries.
- Keep typed domain reason atoms internally and map them to API/UI-safe responses at transport boundaries.
- Treat internal invariants as contracts and avoid defensive branching for impossible internal states.

## Defer Protocol

When deferring work, write a short note with:

- **Deferred item**: what is not being built now.
- **Trigger**: condition that makes this work necessary later.
- **Extension point**: where future work should attach.
- **Impact**: cost/risk of deferring.
- **Next step**: smallest follow-up action when trigger occurs.
