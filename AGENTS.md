# Agent Guide

This is an Elixir/Inertia template app built on Phoenix. Phoenix owns routes, auth, persistence, background jobs, and server truth. React receives page props through Inertia.

Read `docs/DESIGN_PRINCIPLES.md` for the design principles of this app.

Read `docs/CODE_STYLE_GUIDANCE.md` for code review preferences and code style guidance.

## Module Architecture Contract (Read First)

`## Module Design Defaults (Elixir)` in this file is a core implementation contract, not optional guidance.

- Treat that taxonomy as the default for every new application module
- Keep interaction rules strict so boundaries stay clear
- If a module is intentionally outside the taxonomy, including cross-cutting policy modules like authorization, document the boundary and reason in `@moduledoc` or PR notes
- Do not create new broad module categories unless there is repeated, concrete pressure that the existing taxonomy cannot handle
- Prefer deleting example scaffolding once a real domain replaces it

## Project Structure

- `lib/arnor` contains application contexts, schemas, services, finders, values, Oban workers, mailer, release tasks, and Repo
- `lib/arnor_web` contains routing, controllers, auth plugs, endpoint, telemetry, and Phoenix components/layouts
- `lib/arnor/organizations` is the real example domain for handlers, services, finders, and values
- `assets/js/pages` contains Inertia page components
- `assets/js/components/ui` contains reusable shadcn-style UI primitives
- `assets/js/layouts` contains Inertia layouts
- `test/support/factory.ex` owns ExMachina factories
- `test/support/test_helpers.ex` owns non-factory test helpers
- `priv/repo/migrations` starts from clean template migrations, not copied product history

## Documentation Style

- No trailing periods in `@doc` and `@moduledoc` strings
- Add `@doc` or `@spec` where caller-facing behavior, side effects, or return contracts are non-obvious or frequently reused
- Skip boilerplate docs/specs when they do not add clarity
- Keep template docs generic; do not bake one deployment host, provider, customer, or product workflow into reusable guidance

## Project Guidelines

- Use `mix precommit` when you are done with backend changes and fix pending issues
- Use the included `Req` library for HTTP requests; avoid HTTPoison, Tesla, and direct `:httpc`
- Keep Phoenix as the source of truth; do not duplicate server-owned state in React
- Use Inertia for server-rendered page props and React pages
- Keep organizations and memberships as the reusable SaaS-style account foundation
- Keep Oban installed for retryable background work, but do not add queues or cron jobs until a real domain needs them
- Use Swoosh for email and keep production adapter configuration runtime-driven
- Use Bodyguard for authorization policies that cut across domains

## Xamal Deployment

Xamal is the deployment path for this app. It builds the named `arnor` release, deploys over SSH, runs the app with systemd, and serves traffic through Caddy.

- Use `mix xamal.setup` to bootstrap and deploy after explicit production approval
- Use `mix xamal.deploy` for normal deploys after bootstrap
- Use `mix xamal.iex` for remote IEx
- Use `mix xamal.app.logs -f` for application logs
- Use `mix xamal.migrate` for release migrations
- Use `mix xamal.details` for deployed service/proxy status
- Use `mix xamal.rollback VERSION` to roll back to a prior release
- Run Xamal build/deploy commands from a Linux x86_64 environment compatible with Hetzner; macOS release tarballs are not deployable to Linux
- Keep deployment config in `config/xamal.exs`
- Keep app secrets in `.env`, `.env.local`, CI, or deploy environment variables consumed by `.xamal/secrets`
- Try the existing 1Password SSH agent before setting `XAMAL_SSH_KEY_DATA` from `op read`
- On this workstation, use `XAMAL_SSH_KEY_DATA` for Xamal commands because Erlang SSH does not authenticate through the 1Password SSH agent
- Do not commit private key material, production secrets, private hostnames, or one-off production aliases
- Do not deploy, bootstrap, remove old runtime state, or uninstall server packages without James's explicit approval in the active conversation

## First-Principles Iteration

- Do not optimize around an existing implementation unless compatibility is explicitly required
- Prefer the simplest code that expresses the real product path; do not add defensive checks, helpers, fallback branches, or abstractions unless the current behavior needs them
- Assume internal contracts hold after the boundary validates them; let broken internal/provider contracts fail loudly instead of obscuring them with extra code
- This template is meant for early-stage product software: expect to throw away code, rewrite flows, change abstractions, tighten contracts, and delete behavior that no longer serves the current product
- Start from the route, screen, job, or domain behavior needed now; then design the smallest data contract and implementation for that need
- Treat legacy shapes, old props, fallback behavior, and broad compatibility as traps unless there is a concrete reason to preserve them
- Do not preserve unused fields, duplicated logic, or historical behavior just because tests or existing code currently expect them
- When performance work reveals a bad abstraction, replace the abstraction instead of making the old abstraction faster
- If preserving old behavior would materially complicate the solution, ask whether that behavior is still required

## Delivery Cadence

- For non-trivial work, plan first and execute in small, reviewable chunks
- Check in at agreed phase boundaries and incorporate review feedback before continuing
- If direction is unclear or assumptions could change architecture, security posture, data integrity, or irreversible behavior, stop and ask for clarification
- Prefer a working, testable vertical slice over partial architecture

## Provider Configuration

- Keep provider selection config-driven through one explicit default provider setting when a provider boundary exists
- Require credentials based on the selected provider instead of forcing every provider credential in all environments
- Add provider defaults to config only after a real provider exists
- Do not hardcode provider base URLs, API keys, webhook secrets, or credentials in modules

## Authentication And Routing

- Always handle authentication flow at the router level with proper redirects
- Use `ArnorWeb.UserAuth` plugs for authenticated and unauthenticated routes
- `phx.gen.auth` assigns `current_scope`; it does not assign `current_user`
- Do not introduce `current_user` assigns in templates; derive the user from `@current_scope.user`
- Pass `current_scope` as the first argument to context/domain functions that need caller context
- When performing queries scoped to the actor, filter through `current_scope.user`
- Place routes that require authentication in a scope that sets `:require_authenticated_user`
- Controllers automatically have `current_scope` available if they use the `:browser` pipeline
- Anytime logged-in content or `current_scope` behaves incorrectly, check router scope and plugs before changing controller or page logic

## Module Design Defaults (Elixir)

This taxonomy is the default shape for application code. Use it as a pragmatic middle ground: lighter than full DDD/hexagonal overhead, but more structured than ad-hoc growth.

### Handlers

- Top-level orchestrators
- Domain/business-facing
- Named after the domain object or workflow a human recognizes, not the transport or provider details
- Can expose multiple public functions for distinct domain use cases
- Public function names should be explicit about behavior for the use case
- Call Services, Finders, and Values, but do not directly mutate/build core data structures
- Keep controller layers thin and readable
- SOLID SRP: handlers own orchestration only, not low-level read/write implementation
- SOLID DIP/OCP: handlers depend on service/finder/value boundaries so new flows can be composed without rewriting controllers
- Example module/file: `Arnor.Organizations.Handlers.OrganizationInvite` at `lib/arnor/organizations/handlers/organization_invite.ex`

### Services

- The action/write arm of the system
- Execute application and infrastructure changes such as DB writes, side effects, and logging
- Can call Services, Finders, and Values
- Should not call upstream Handler or Controller layers
- Must be action-oriented and named for a single operation
- Service module names must provide action clarity even when exposing a generic `call/1`
- Avoid unclear noun-only service names
- SOLID SRP: each service performs one action and contains only the side effects for that action
- SOLID OCP/LSP: callers rely on clear action contracts, so implementations can change without changing handler/controller call sites
- Example module/file: `Arnor.Organizations.Services.CreateOrganizationInvitation` at `lib/arnor/organizations/services/create_organization_invitation.ex`

### Finders

- Read/query-only counterpart to Services
- Focused lookup/read operations such as DB/API fetches
- Keep them simple and avoid calling other Finders when possible to limit complexity
- Usually expose one public function, for example `find/1` or `list/1`
- Should return data, `{:error, :not_found}`, or empty collections as appropriate and never perform writes
- SOLID SRP: each finder owns one query concern and keeps read logic out of handlers/services
- SOLID ISP/DIP: callers depend on small read contracts instead of reaching into query internals
- Example module/file: `Arnor.Organizations.Finders.FindPendingOrganizationInvitation` at `lib/arnor/organizations/finders/find_pending_organization_invitation.ex`

### Values

- Data transfer/composition layer used by all other patterns
- Build and reshape maps/lists/structs for passing and output
- Keep merge/filter/reshape logic here instead of scattering it across handlers/services/finders
- Usually expose one public function, for example `build/1`
- Values are DTO-like and should usually map closely to the underlying Ecto schema shape
- Use Values for API and Inertia prop shaping when the shape is reused or would otherwise make controllers/services noisy
- SOLID SRP: values only transform/compose data shapes and avoid policy or side effects
- SOLID OCP: add new representation modules instead of expanding branching logic in controllers/services
- Example module/file: `Arnor.Organizations.Values.Invite` at `lib/arnor/organizations/values/invite.ex`

### Workers

- Oban workers are durable execution boundaries, not business-logic buckets
- Workers should end in `Worker`
- Namespace workers by domain, for example `Arnor.Billing.Workers.SyncSubscriptionWorker`
- Keep `perform/1` thin and delegate domain behavior to Services, Handlers, or Finders
- Workers map service outcomes to retry/discard behavior
- Do not return Oban-specific `{:discard, ...}` tuples from Services
- Example module/file: `Arnor.Billing.Workers.SyncSubscriptionWorker` at `lib/arnor/billing/workers/sync_subscription_worker.ex`

### Contexts

- Primarily for CRUD-like operations on Ecto schemas
- Keep policy and orchestration decisions out of contexts; handle those in Handlers or Services before calling context functions
- Contexts are acceptable for straightforward schema operations, but do not let them become mixed-purpose god modules

### Controller/Handler/Service Flow

- Controllers handle transport concerns: HTTP params, headers, status codes, redirects, flash, and Inertia props
- Only bubble named errors when a caller can make a specific recovery or response decision from that name; otherwise handle the error at the boundary that has enough context
- Controllers may call one or two Services directly when the flow is simple and no orchestration layer is needed
- Introduce a Handler when orchestration/branching across multiple Services/Finders is needed
- Do not add a Handler when a single Service call is sufficient
- For webhook/provider flows, use one static webhook route/controller per provider; do not use dynamic `:provider` webhook routes
- Webhook controllers should parse provider-specific typed webhook structs at the boundary before handing off
- A Handler can process inline with Services or enqueue a Worker when durability/replay guarantees are needed
- Provider-specific event processing belongs in action-oriented Services

### Naming Conventions (Strict)

- Handlers: domain noun/workflow modules with behavior-explicit methods
- Services: action-clarity modules, typically exposing `call/1`
- Finders: read intent in the name, for example `FindOrganizationInvitationByToken`
- Values: schema-aligned or prop-shape-aligned names, for example `Invite` or `Member`
- Workers: action-oriented and ending in `Worker`
- Names must describe the job to a human at the call site
- Do not name modules/functions after API mechanics, data shape, or generic containers unless the API concept is also the product/domain concept
- If a name could fit ten unrelated places, it is too generic

### How They Interact

- Typical simple flow: Controller -> Service -> Value -> Inertia props/API response
- Typical orchestrated flow: Controller -> Handler -> Service/Finder -> Value -> Inertia props/API response
- Durable background flow: Controller/Service -> enqueue Worker -> Service/Handler/Finder -> typed outcome -> Worker retry/discard mapping
- Provider webhook flow: ProviderWebhookController -> Webhook Handler -> Provider-specific Service -> Context/Repo, optionally via Worker
- The main benefit comes from strict interaction rules and single-responsibility boundaries

### Exception Protocol

- If a module does not fit one of these categories, treat it as an explicit exception
- Document the exception and why the taxonomy did not fit
- Keep exceptions narrow and prefer composing existing roles over inventing new umbrella types
- Cross-cutting modules such as authorization can be exceptions, but they still need a clear boundary

## Oban Defaults

Use Oban for asynchronous and retryable processing.

- Define explicit queue and retry policy in each worker with `use Oban.Worker, queue: :default, max_attempts: ...`
- Default to `:default` queue unless there is a clear isolation/throughput need and matching queue config in `config/*.exs`
- Make external side effects idempotent and use Oban uniqueness when duplicate execution is unsafe
- Return `{:discard, reason}` for non-retryable failures and `{:error, reason}` for retryable failures from workers
- Do not broadly rescue unexpected exceptions inside workers or worker-called services; let them crash so Oban records the exception, stacktrace, and attempt details
- Only convert expected domain or provider failures into `{:error, reason}` or `{:discard, reason}` tuples when the worker can make a deliberate retry/discard decision
- Do not swallow failures from finalization or follow-up orchestration steps; propagate `{:error, reason}` back from the worker so Oban can retry or record the failure
- Prefer small, contextual log lines at worker boundaries and failure branches; avoid replacing structured Oban errors with vague string messages
- Tests run with `config :arnor, Oban, testing: :manual`; use `Oban.Testing` helpers to assert and execute jobs explicitly

## Frontend Conventions

- Read page props with `usePage<Props>().props`
- Keep page-specific prop types in the page file
- Move shared model types to `assets/js/types/models.ts` only after reuse exists
- Use `useForm` for forms submitted to Phoenix
- Reuse `assets/js/components/ui` before creating new components
- Use Tailwind directly unless a shared component already exists
- Do not add memoization by default; prefer simpler component boundaries
- Do not recreate server state in React; the server is the source of truth
- If a prop needs to change, make the smallest matching controller change and update TypeScript at the same time

## Test Guidelines

- Prefer high-value integration tests over unit tests
- The most valuable tests drive the system from an external boundary, such as a controller or webhook endpoint, through real application code, real database writes, real Oban enqueueing/execution, and real storage/client boundaries
- Avoid mocking internal domain/application modules in integration tests
- For external service boundaries, use centralized test stubs and Mimic the client module the production flow already calls
- Keep external-boundary expectations visible in the test with `Mimic.expect(...)`; support modules should provide reusable return values/responses, not hide expectation setup
- When a full-flow test already proves important behavior, remove redundant lower-level happy-path tests unless they cover a distinct failure mode, idempotency rule, validation contract, or hard-to-reproduce edge case
- Use ExMachina for test data setup across the codebase
- Keep factories centralized in `test/support/factory.ex` (`Arnor.Factory`)
- Keep non-factory testing helpers in `test/support/test_helpers.ex` (`Arnor.TestHelpers`)
- `Arnor.DataCase` and `ArnorWeb.ConnCase` import `Arnor.Factory` and `Arnor.TestHelpers`
- Test files should use `insert/2`, `build/2`, `params_for/2`, and `string_params_for/2`
- Do not add new fixture modules for domain data generation; prefer factory traits/overrides in the shared factory file
- For validation/constraint tests, start from `params_for(...)` and override only the invalid field under test
- Test names must clearly describe the exact behavior under test so failures are self-explanatory
- Each test should verify one distinct behavior, though it may have many assertions
- Prefer expressive variable names so test intent is obvious without extra comments
- Keep setup and mocking minimal and obvious; prefer one setup path per test module unless splitting adds clear value
- Do not add public production APIs only to make tests easier; prefer dependency injection at existing boundaries
- Only add comments in tests when naming alone cannot communicate intent
- Always use `start_supervised!/1` to start processes in tests so cleanup happens between tests
- Avoid `Process.sleep/1` and `Process.alive?/1` in tests
- Instead of sleeping to wait for a process to finish, use `Process.monitor/1` and assert on the DOWN message
- Instead of sleeping to synchronize before the next call, use `_ = :sys.get_state(pid)` to ensure the process handled prior messages

## Elixir Guidelines

- Elixir lists do not support index-based access via access syntax; use `Enum.at`, pattern matching, or `List`
- For `if`, `case`, `cond`, and other block expressions, bind the result of the expression instead of rebinding inside it
- Never nest multiple modules in the same file; it can cause cyclic dependencies and compilation errors
- Never use map access syntax on structs; access fields directly or use struct-specific APIs such as `Ecto.Changeset.get_field/2`
- The standard library covers date/time manipulation; do not add dependencies unless the project explicitly needs parsing behavior
- Do not use `String.to_atom/1` on user input
- Predicate function names should not start with `is_`; use a trailing question mark instead
- OTP primitives such as `DynamicSupervisor` and `Registry` require names in child specs
- Use `Task.async_stream/3` for concurrent enumeration with back-pressure
- Prefer `timeout: :infinity` for `Task.async_stream/3` when timeout would create false failures around long-running but valid work

## Mix Guidelines

- Read task docs and options before using tasks with `mix help task_name`
- To debug test failures, run a specific file with `mix test test/path/to_test.exs` or run all previous failures with `mix test --failed`
- `mix deps.clean --all` is almost never needed; avoid it unless there is a concrete dependency corruption reason

## Ecto Guidelines

- Prefer keyword-style Ecto queries over pipe-based queries, for example `from user in User, where: ...`
- Avoid single-letter variables; use descriptive names like `invitation`, `organization`, or `membership`
- Always preload Ecto associations in queries when they will be accessed in templates or page props
- Remember to import `Ecto.Query` and supporting modules when writing `seeds.exs`
- Ecto schema fields use the `:string` type even for `:text` columns
- `Ecto.Changeset.validate_number/2` does not support `:allow_nil`; validations only run if a change exists and the value is not nil
- Use `Ecto.Changeset.get_field/2` to access changeset fields
- Fields set programmatically, such as `user_id`, must not be listed in `cast` calls; set them explicitly when creating the struct
- Always invoke `mix ecto.gen.migration migration_name_using_underscores` when generating migration files so timestamps and conventions are correct

## Phoenix Guidelines

- Remember Phoenix router `scope` blocks include an optional alias that prefixes all routes within the scope
- You do not need to create your own alias for route definitions; the `scope` provides the alias
- `Phoenix.View` is no longer needed or included with Phoenix; do not use it
- Phoenix templates use `~H` or `.html.heex`, never `~E`
- Use `Phoenix.Component.form/1` and `Phoenix.Component.inputs_for/1`; do not use `Phoenix.HTML.form_for` or `Phoenix.HTML.inputs_for`
- When building forms, use `Phoenix.Component.to_form/2`, pass the form assign to `<.form>`, and access fields through `@form[:field]`
- Always add unique DOM IDs to key elements such as forms and buttons so tests can target them
- Phoenix v1.8 moved `<.flash_group>` to the Layouts module; do not call `<.flash_group>` outside layouts
- Use imported core components such as `<.input>` when available
- If overriding default input classes, provide the full styling because default classes are not inherited
- HEEx class attrs support lists; use list syntax for conditional/multiple classes
- Never use `<% Enum.each %>` or non-for comprehensions for generated template content; use `<%= for item <- @collection do %>`
- HEEx HTML comments use `<%!-- comment --%>`
- Use `{...}` interpolation inside tag attributes and for values in tag bodies
- Use `<%= ... %>` for block constructs such as `if`, `cond`, `case`, and `for` in tag bodies

## LiveView Guidance

This template primarily uses Inertia. These rules apply if a project adds LiveViews or edits existing LiveView code.

- Avoid LiveComponents unless there is a strong, specific need
- Name LiveViews with a `Live` suffix
- Use streams for large or changing collections instead of assigning regular lists
- Do not use deprecated `phx-update="append"` or `phx-update="prepend"`
- If a JS hook manages its own DOM, set `phx-update="ignore"` and provide a unique DOM ID
- Never write raw embedded `<script>` tags in HEEx; use colocated hooks when inline hook behavior is needed
- Use `push_event/3` when server code needs to push events/data to a JS hook
- Always return or rebind the socket from `push_event/3`
- LiveView tests should use `Phoenix.LiveViewTest` and `LazyHTML`
- Prefer `element/2`, `has_element?/2`, and stable selectors over raw HTML string assertions

## Preserve These Template Pieces

- Phoenix/Inertia request flow and shared auth props
- Auth plus organization/membership/invitation foundation
- Oban installation and default queue pattern
- Handler/Service/Finder/Value taxonomy examples under `lib/arnor/organizations`
- ExMachina factory and test helper conventions
- CI scaffold that can grow into frontend/backend checks when a new project is ready
- Xamal, Caddy, and systemd deployment guidance
- `README.md`, `.env.example`, and this guide as onboarding contracts

## Delete Before Abstracting

When product-specific code no longer belongs in a new project, delete it. Do not build a generic framework around one app's old behavior.
