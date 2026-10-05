# Code checks

Run `mix check` before handing off a change. It runs every configured check, reports failures, and exits nonzero when any check fails

```sh
mix check
mix check --only credo
mix check --only unused
mix check --retry
mix check --format agent
```

The runner uses the test build for compilation, formatting, source analysis, and tests. Set `MIX_TEST_PARTITION` to a distinct value when another checkout may be testing. Normal runs do not rewrite files or automatically skip checks that passed earlier

## What owns each check

- **Elixir compiler and Boundary:** compiler warnings fail the check. Boundary permits the web layer to use the domain's exported modules, while preventing domain calls into the web layer. Application startup has its own boundary so it can supervise both. ConnCase is test infrastructure and can access both layers
- **Formatter:** `mix format` uses Styler for Elixir and Phoenix's HTML formatter for HEEx. The migration directory retains its existing Ecto formatter. Review Styler changes before accepting them because its rewrites can affect behavior
- **Credo:** checks readability, complexity, and suspicious code. `.credo.exs` disables rules already owned by Styler and does not require boilerplate module docs or typespecs. Date-based MCP version names are allowed
- **ExSlop:** selected Credo checks flag swallowed errors, redundant results, identity transformations, in-memory query filtering, queries in loops, dual atom/string key access, and narrator documentation
- **Jump:** selected Credo checks catch ineffective LiveView assertions, function-level `else`, global logger changes in tests, unguarded PubSub subscriptions in `mount/3`, and undeclared compile-time file dependencies. Its configurable forbidden-function check rejects `Process.sleep/1` in tests
- **Excellent Migrations:** runs inside Credo for migrations after `20260906023636`. It analyzes source without executing migrations. James approved this historical cutoff; new migrations receive every configured safety check
- **Sobelow:** checks application security. Dependency-version checks are excluded here because the dependency auditors own them
- **Hex audit and mix_audit:** check retired/vulnerable dependencies using their respective advisory sources. Keep both: the initial run found Hex advisories that `mix_audit` did not report
- **ExDNA:** rejects exact duplicate blocks of at least 30 AST nodes appearing three or more times in `lib`. This follows the project's rule of three rather than forcing an abstraction for every pair
- **Reach:** checks for unused pure expressions and known side effects in Momentum and Value modules. It allows exceptions and unresolved effects, so it does not prove purity. Broad smell checks remain available for investigation but are not duplicated in the default lint run
- **mix_unused:** reports unused public functions and functions that could be private. `mix.exs` lists dynamic framework entry points, configured OAuth callbacks, MCP dispatch, and release commands that the tracer cannot discover. Findings are hints during normal compilation and failures in the runner's separate `unused` check
- **xref:** rejects compile-connected cycles, which can cause unnecessary recompilation. It does not prohibit every runtime dependency cycle
- **ExUnit:** runs the existing full test suite
- **Unused dependency locks:** reports stale entries in `mix.lock`

No additional Credo rule packages are needed for this setup. The chosen checks use Credo itself, ExSlop, and Jump

## Working with findings

Run `mix format path/to/file.ex` to apply formatting to selected files. A bare `mix format` may rewrite much of the existing codebase through Styler

The initial findings were resolved by formatting, simplifying nested flows, removing unused APIs, updating vulnerable dependencies, removing a stale lock entry, and moving the MCP registry out of compile-time attributes. Browser responses now carry a CSP; the theme bootstrap is a synchronous same-origin asset

### Reviewed exceptions

- `Mmentum.Habits.Values.Habit.schema/0` is called at compile time by `ListHabits` to compose its Zoi result schema. The unused-code tracer misses that call, so it has a single-function exception

- The migration cutoff accepts 55 historical warnings without rewriting schema history: new-table indexes and foreign keys, extension SQL, constant defaults, column removals, constraint validation, and rollback table drops. Removals and validation remain real rollout hazards; the cutoff does not establish that historical migrations are safe to run against a populated database
- `.sobelow-skips` contains only the existing HTTPS and OAuth action-reuse findings. Fly's `force_https` owns TLS redirects. Reassess this exception if deployment topology changes. GET authorization cannot approve consent: POST alone verifies the signed request and supplies the private decision; CSRF protection and a single-use bound nonce guard approval. Tests exercise copied GET fields, missing CSRF, tampering, and replay
- The browser pipeline's `Config.CSP` annotation accounts for its dynamically built header, including the endpoint's exact WebSocket origin. The policy blocks inline scripts and objects, while allowing existing inline styles, Google Fonts, and Splitbee origins. Consent pages allow the validated callback origin in `form-action`, since Chromium also checks redirects after form submission. Splitbee's configured script returned HTTP 410 during inspection; its existing integration remains unchanged
- `icon/1` skips `XSS.Raw` because SVG markup comes only from checked-in Heroicons read at compile time. Runtime input selects a known map key, never arbitrary markup

Treat analyzer findings as evidence to inspect. In particular, `mix_unused` does not track test-file calls or all dynamic dispatch, and some functions must remain public for framework use. Add a narrow exception only after identifying the caller or framework contract

ExSlop 0.4.5 caught an explicit `try/rescue` in the setup probe but missed the equivalent function-level rescue. Styler can produce that latter form, so this check alone does not enforce the whole error-handling policy

For deeper manual analysis:

```sh
mix reach.check --smells
mix reach.map --coupling
mix xref graph --format cycles --label compile-connected
```

Boundary is a compile-time dependency in every environment because application modules use its macro. The other added tools are development/test dependencies and do not enter the production runtime
