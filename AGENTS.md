# Mmentum Agent Guide

Mmentum is an identity-based habit tracker built with Elixir, Phoenix LiveView, Ecto and PostgreSQL. Phoenix owns routing, authentication, persistence and server truth. HEEx renders the UI; JavaScript hooks handle browser interactions and charts.

Read `docs/DESIGN_PRINCIPLES.md` and `docs/CODE_STYLE_GUIDANCE.md` before implementation or review. Their design and style principles apply; references to template tooling are not requirements to install it. Verify the actual stack in `mix.exs` and the code. Read `VISION.md` and relevant `PLAN_*.md` for product context, but do not treat planned features as implemented behavior or approval to expand scope.

## Design And Collaboration Defaults

- Prefer familiar framework and language conventions. Principle of least surprise: A reader should find behavior where they expect it
- Parse and validate external input at the earliest I/O boundary. Pass validated values inward and don't repeat those checks. Business rules and authorization still belong where the operation runs
- Keep related decisions together under one clear owner. Avoid scattering the same knowledge across modules or adding layers that merely pass it along
- Judge correctness independently of the implementation. Passing tests are not enough when their expectations repeat the code's assumptions

## Project Structure And Stack

- `lib/mmentum` contains domain contexts, schemas, calculations, values, Repo, mailer and release tasks
- `lib/mmentum/habits.ex` owns habit operations; `lib/mmentum/logs.ex` owns completion queries
- `lib/mmentum/habits/momentum.ex` calculates momentum; `lib/mmentum/habits/values/momentum_series.ex` shapes chart output
- `lib/mmentum/time.ex` owns local calendar boundaries and time formatting, using the configured `Tz` time zone database
- `lib/mmentum_web` contains the router, controllers, auth hooks, LiveViews, components, layouts and endpoint
- `lib/mmentum_web/live/habit_live` contains the dashboard, detail view and habit form component
- `assets/js/hooks` contains browser hooks; `assets/css` contains Tailwind and application styles
- `test/support/fixtures` contains the existing account and habit fixtures; `test/support/data_case.ex` and `conn_case.ex` own database and connection setup
- `priv/repo/migrations` contains the application's real schema history
- `config/runtime.exs`, `Dockerfile`, `fly.toml` and `rel` define runtime configuration and deployment
- HTTP uses the installed Finch client; mail uses Swoosh; the endpoint uses Bandit
- Use the existing dependencies and boundaries. Do not add a framework, test library or background job system merely to satisfy generic guidance

## Local Commands And Validation

- Read task docs and options first with `mix help task_name`
- Local tool versions are in `.mise.toml` and `.tool-versions`; `mix.exs` requires Elixir 1.20. Node 24 is configured for assets
- `mix setup` installs dependencies, creates/migrates/seeds the development database and builds assets
- Start locally with `mix phx.server` or `iex -S mix phx.server`
- Run focused tests with `mix test test/path/to_test.exs`, then the complete `mix test` suite
- The test alias creates and migrates the local test database. `config/test.exs` uses PostgreSQL on localhost and database `mmentum_test#{MIX_TEST_PARTITION}`; use a distinct partition when another checkout may be testing
- For backend changes, run `mix format --check-formatted` and `mix compile --warnings-as-errors` as well as tests; fix failures before completion
- Use `mix test --failed` to rerun previous failures
- Asset tasks are `mix assets.setup`, `mix assets.build` and `mix assets.deploy`; inspect their aliases before running installs or builds
- Avoid cleaning all dependencies unless there is concrete evidence of corruption
- Never run destructive database tasks against shared or production databases without explicit approval

## Fly Deployment

The checked-in deployment path is a Docker-built `mmentum` release on Fly. `fly.toml` configures the app, HTTP service and `/app/bin/migrate` release command; `Dockerfile` builds assets and the release, then starts `/app/bin/server`.

- Runtime production configuration requires `DATABASE_URL` and `SECRET_KEY_BASE`; it also reads `PHX_HOST`, `PORT`, `POOL_SIZE`, `ECTO_IPV6` and `PHX_SERVER`
- Keep secrets in the deployment environment, not modules or checked-in files
- Build Linux releases with the deployment container; local macOS release artifacts are not Linux deployables
- Treat migrations as real data changes: validate forward and reverse behavior on a local test database, and disclose existing-data risks
- Do not silently repair or delete existing production data to make a migration pass
- Do not deploy, change Fly resources or secrets, run production migrations, or remove runtime state without James's explicit approval in the active conversation
- Do not commit private keys, production secrets, private hostnames or one-off production aliases

## First-Principles Iteration And Delivery

- Plan non-trivial work and execute in small, reviewable, testable slices
- Check in at agreed phase boundaries and incorporate feedback before continuing
- If a decision changes architecture, security posture, data integrity or irreversible behavior, stop and ask
- Start from the route, screen or domain behavior needed now, then choose the smallest data contract and implementation
- Prefer the simplest code that expresses the real product path; do not add defensive checks, helpers, fallback branches or abstractions without a current need
- Assume internal contracts hold after boundary validation. Let broken internal/provider contracts fail clearly rather than obscuring them with fallback data
- Do not optimize around existing implementation details unless compatibility is explicitly required
- Do not preserve unused fields, duplicated logic or historical behavior merely because tests expect them
- If preserving old behavior would materially complicate a solution, ask whether it is still required
- When performance work reveals a bad abstraction, replace it rather than making it faster
- Prefer deleting obsolete behavior to building a generic framework around it
- Keep provider selection and credentials config-driven when a real provider boundary exists; do not add speculative provider configuration or hardcode URLs and credentials in modules

## Module Architecture Contract

The following taxonomy is the default for new application modules, not an instruction to split every existing context into layers. Reuse the smallest existing boundary that owns the behavior. Do not introduce broad module categories without repeated, concrete need.

### Module Design Defaults (Elixir)

**Handlers**

- Top-level domain/workflow orchestrators, named for an action or object a human recognizes, not transport mechanics
- May expose multiple behavior-explicit public functions for distinct use cases
- Call Services, Finders and Values; do not implement low-level writes or core data shaping
- Introduce one only when orchestration or branching across multiple operations needs an owner

**Services**

- The action/write arm: one operation owning its database writes, side effects and relevant logging
- Use action-oriented module names that remain clear at a generic `call/1` call site
- May call Services, Finders and Values, not upstream Handlers, LiveViews or Controllers
- Keep return contracts clear so callers do not inspect storage internals

**Finders**

- Read/query-only operations, named for the lookup, usually exposing `find/1` or `list/1`
- Own one query concern and return data, a meaningful not-found error or an empty collection
- Never perform writes; avoid chaining Finders when a simple query suffices

**Values**

- Pure map/list/struct composition and output shaping, usually exposing `build/1`
- Keep reused or noisy representation logic here instead of scattering it across callers
- No policy or side effects; names should match the schema or presentation concept
- Existing example: `Mmentum.Habits.Values.MomentumSeries`

**Contexts**

- Own straightforward schema operations and focused domain APIs
- Keep them cohesive rather than growing mixed-purpose god modules
- Use Handlers or Services when orchestration/policy complexity requires a separate owner, not for pass-through wrappers

**Workers**

- If background execution becomes necessary, keep the execution boundary thin and named with a `Worker` suffix
- Delegate domain behavior to existing application boundaries; execution-specific retry decisions belong at the worker boundary, not in Services
- Make repeated side effects idempotent and propagate failures rather than swallowing them
- This convention does not authorize introducing background infrastructure

### Interaction And Naming Rules

- LiveViews and Controllers own transport/UI concerns: events, params, headers, forms, status codes, navigation and flash
- A simple flow may call a context or one or two Services directly. An orchestrated flow calls a Handler, then Services/Finders and Values
- Only bubble named errors when a caller can make a specific recovery or response decision
- If provider webhooks are added, use static provider-specific routes and parse typed events at the I/O boundary before handing off
- Names must describe the job at the call site. Avoid generic containers or API mechanics unless they are also the domain concept
- Keep one spelling per concept and use descriptive variables rather than single-letter query bindings
- Document intentional taxonomy exceptions and their boundaries in `@moduledoc` or change notes. `Mmentum.Habits.Momentum` is an existing pure-calculation exception
- No trailing periods in `@doc` or `@moduledoc`; add docs/specs only when behavior, side effects or reused return contracts need clarification

## Authentication And Domain Integrity

- Preserve the existing `MmentumWeb.UserAuth` router plugs and LiveView `on_mount` hooks
- This app assigns `current_user`; LiveViews access it through `get_current_user(socket)`. Do not substitute a different generated-auth convention
- Authenticated routes require both the appropriate browser pipeline and authenticated live session
- Check router scopes and auth hooks first when current-user behavior is wrong
- Pass the user as the first argument to ownership-sensitive domain calls and scope reads and writes to that user
- Fields such as `user_id` are assigned programmatically, not accepted through `cast`
- Habit writes that depend on stored state must use the existing habit-row lock inside the transaction
- Dashboard undo is limited to the current local habit period, never unrestricted history deletion
- A flexible maximum is optional; when present it must be strictly greater than the minimum
- Use local calendar dates to identify day/week/month periods, not fixed-duration arithmetic on zoned timestamps
- Query periods use inclusive UTC start and exclusive next start. Resolve missing/overlapping local midnights deliberately
- Keep time-dependent UI refresh at the local period boundary; do not add polling or tab-reactivation refresh without approval

## Phoenix, LiveView And Frontend Conventions

- Keep server-owned state in Phoenix; hooks should not recreate domain truth in the browser
- Reuse `MmentumWeb.CoreComponents`, `HabitComponents` and layouts before creating new UI primitives
- Follow existing LiveView namespaces such as `HabitLive.Index` and `HabitLive.Show`; keep LiveComponents focused on a real reusable/stateful need
- Use verified `~p` routes. Router scopes already provide their declared aliases
- Render with `~H` or `.html.heex`, and use `Phoenix.Component.to_form/2`, `<.form>` and `<.input>` for forms
- Add stable unique DOM IDs to forms and key controls; prefer accessible labels and native semantics
- Use class lists for conditional HEEx classes, `{...}` for values/attributes and `<%= ... %>` for block expressions
- Generate repeated markup with comprehensions, not `Enum.each`; HEEx comments use `<%!-- ... --%>`
- When overriding default component styles, provide the full required classes
- Use streams for changing collections where appropriate; do not use deprecated append/prepend updates
- Give hook-owned DOM a stable ID and an explicit ownership boundary such as `phx-update="ignore"` when the hook alone manages its children
- Keep hooks in the existing assets structure rather than embedding raw script tags in HEEx
- Use and return/rebind `push_event/3` when server events must reach a hook
- Preserve hook cleanup on destruction and reduced-motion behavior
- Use Tailwind and existing design tokens/components; avoid speculative memoization or extra client frameworks

## Test Guidelines

- Prefer high-value LiveView/controller/domain integration tests through real application code and PostgreSQL writes
- Do not mock internal domain modules. If an external service needs a test boundary, keep expectations visible and setup centralized without adding a test dependency by default
- Reuse `Mmentum.AccountsFixtures` and `Mmentum.HabitsFixtures`; use the existing `DataCase` and `ConnCase` sandbox setup for ordinary database tests
- For validation tests, start with valid fixture attributes and override the field under test
- Keep each test focused on a distinct behavior and use names that explain exactly what failed
- Remove redundant happy-path tests when an integration test already proves the behavior; retain distinct failure, concurrency, constraint and calendar edge cases
- Do not add public production APIs solely to ease testing
- Keep setup minimal and comments limited to constraints that names cannot explain
- Start test processes with `start_supervised!/1`; use messages, monitors or `:sys.get_state/1` for deterministic coordination, not `Process.sleep/1` or `Process.alive?/1`
- Concurrency tests need independent database connections and explicit coordination; shared sandbox access alone does not prove locking behavior
- Use `Phoenix.LiveViewTest` with `element/2`, `has_element?/2` and stable selectors; existing HTML parsing dependencies include Floki and LazyHTML
- LiveView tests do not execute JavaScript or prove browser layout/accessibility behavior; report those validation gaps honestly

## Elixir And Ecto Guidelines

- Keep one module per file; do not nest modules
- Bind the result of `if`, `case` and `cond` rather than rebinding inside their branches
- Lists do not support index access syntax; use pattern matching, `Enum.at/2` or `List`
- Use struct fields and struct-specific APIs such as `Ecto.Changeset.get_field/2`, not map access syntax on structs
- Do not convert untrusted strings to atoms dynamically
- Predicate names use a trailing `?`, not an `is_` prefix
- Name supervised OTP resources such as Registries and DynamicSupervisors explicitly
- Use `Task.async_stream/3` for concurrent enumeration with back-pressure; use `timeout: :infinity` when valid work should not time out
- Prefer standard-library date/time arithmetic with the existing time zone database over new dependencies
- Prefer keyword-style Ecto queries with descriptive bindings
- Preload associations before templates or values access them
- Ecto schema fields use `:string` even for SQL text columns
- `validate_number/2` has no `:allow_nil` option; it validates changed non-nil values
- Import `Ecto.Query` and required modules when writing seeds
- Generate migrations with `mix ecto.gen.migration migration_name_using_underscores`; preserve real migration history and test new migration reversibility
