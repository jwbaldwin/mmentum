# MCP Server Specification

The MCP server milestone is complete, with OpenCode as the primary supported client.

## Protocol implementation

Mmentum supports MCP `2026-07-28` and `2025-11-25` at the same `/mcp` endpoint, including discovery and execution of `list_habits`, `get_habit`, `create_habit`, `update_habit`, and `manage_habit_completions`. Their arguments and behavior are listed in [`mcp-tools.md`](mcp-tools.md).

In `2026-07-28`, each request carries its protocol version and client capabilities in `params._meta`. `server/discover` reports supported versions and features; clients can also send an operation directly.

In `2025-11-25`, clients send `initialize`, receive the supported version and server capabilities, then send `notifications/initialized`. Later requests carry `MCP-Protocol-Version: 2025-11-25`. The server also answers `ping`. It does not issue session IDs or use client capabilities to initiate requests back to the client, so no MCP session store is needed. OAuth grants and browser login sessions remain separate.

The official specification defines each version's contract. [`EMCP`](https://github.com/PJUllrich/emcp) supplied implementation examples.

Design decisions:

- Target MCP `2026-07-28`
- Implement protocol features when they improve or enable the user experience
- Keep tool definitions and executors independent from the HTTP transport
- Validate with supported clients, with OpenCode as the primary target
- Keep `2025-11-25` compatibility isolated so it can be removed without changing the newer implementation
- Implement OAuth with maintained libraries rather than writing OAuth itself

## Authorization

Mmentum uses OAuth Authorization Code with PKCE for public clients.

[`attesto_phoenix`](https://github.com/XukuLLC/attesto_phoenix) supplies authorization, token issuance, consent, and public signing keys. Mmentum publishes discovery documents describing the supported flow. `attesto_mcp` supplies protected-resource metadata and bearer-token validation.

The OAuth flow:

- Reuses existing Phoenix login and user sessions
- Offers `mmentum:read` and `mmentum:write` scopes
- Issues five-minute access tokens valid only for this MCP server
- Rotates refresh tokens so approved clients can renew access without another browser approval
- Maps each token to one Mmentum user and an active approved connection
- Lets users review and disconnect clients
- Reads production signing keys from secrets and publishes only public keys through JWKS

AttestoPhoenix 3.2.1 rejects public clients at its revocation endpoint. Mmentum therefore uses browser-owned Connected apps Disconnect as its supported revocation path.

All OAuth routes, including discovery, require HTTPS. MCP requests require a valid bearer token in every environment. Production requires a configured issuer and signing key at startup.

Register public clients through `OAUTH_PUBLIC_CLIENTS_JSON`. Callback addresses must use HTTPS, except that HTTP is allowed for `localhost`, `127.0.0.1`, and `::1`. Startup rejects callbacks without a host or with userinfo or a fragment. Authorization still requires an exact match to a registered address. Dynamic registration and Client ID Metadata Documents are not implemented.

The browser setup page uses PlanetScale's client choices as its starting point at `/users/connections/new`, with ChatGPT, native Pi, and Antigravity CLI added and Claude Managed Agents omitted. Antigravity remains a manual OAuth guide without generated configuration. An optional `setup_client` key links an existing public registration to its client-specific guide. This is presentation metadata, not a new registration or authorization mechanism. See [`docs/MCP_SETUP.md`](docs/MCP_SETUP.md) for keys, callback requirements, and compatibility limits.

## Client compatibility

Local client checks on September 22, 2026:

- **OpenCode 2.0.12:** login, approval, token exchange, discovery, empty tool listing, refresh after expiry, and Disconnect passed with `protocol: "2026-07-28"`.
- **Pi 0.85.1 / pi-mcp-adapter 2.34.0:** the same flow passed with `protocolVersion: "2026-07-28"`.
- **Claude Code 2.1.170:** login, approval, and token exchange succeeded. Token storage failed in the isolated client setup, so automatic refresh was not verified. A separate valid-bearer test reached our request parser but failed because this build uses the older MCP request format. Disconnect invalidated that bearer.

After adding older-protocol support on October 4, Claude Code 2.1.170 connected over local HTTPS with a supplied OAuth access token: initialization, readiness notification, and empty tool listing succeeded. The installed Pi MCP SDK also connected and listed tools in both protocol modes, including an older-protocol ping. These checks cover message compatibility; they do not resolve Claude's earlier token-storage failure or repeat its browser OAuth flow.

On October 9, a temporary Claude Code 2.1.295 CLI connected to the local HTTPS server with a supplied read-only OAuth token. Its debug log confirmed `2026-07-28` negotiation, and the server returned all five implemented tools. Separate live HTTPS calls in both protocol versions checked recent history and complete-history paging, including sending the returned cursor back for the next page. These were direct endpoint calls, not a Claude-driven conversation. No Anthropic account was available, and Claude-managed browser login and refresh remain unverified.

OpenCode and Pi can use the older initialization flow or explicitly select `2026-07-28`. Configure a public client ID, requested scopes, and the exact registered callback address. Public clients need no client secret. A URL alone is insufficient because the server does not register clients automatically.

Local OAuth requires HTTPS. Use the existing `OAUTH_DEV_TLS_CERTFILE` and `OAUTH_DEV_TLS_KEYFILE` settings with a locally trusted certificate, and set `OAUTH_ISSUER` to that HTTPS origin. Keep certificate and key files outside the checkout. The ordinary HTTP development server alone is insufficient for this flow.

Claude, ChatGPT, Codex, and OMP remain unverified. Claude Code's latest connection check covers discovery and tool listing, not its full OAuth flow or agent-driven tool use. These results establish the tested flows, not complete protocol conformance.

## Application shape

The MCP transport and the embedded Mmentum agent will share the same tool modules. Product rules stay in normal application contexts, Services, Finders, and Values rather than in tool definitions or protocol code.

`Mmentum.Tools` is a narrow cross-cutting adapter exception to the normal module taxonomy. It owns the set of tools available to agents without owning the product behavior behind them. `Mmentum.MCP` is a separate transport exception and must not own product behavior.

### Tool interface

`Mmentum.Habits.Values.Habit` owns the public habit schema, generated output type, and single/list builders. Tools compose that schema into their response wrappers and pass queried habits to its builder. The Ecto `Mmentum.Habits.Habit.t()` describes stored records separately.

Use an Elixir behaviour rather than a protocol. Behaviours define a compile-time callback contract for modules. Elixir protocols dispatch on the type of a value, which does not match a fixed catalog of named tools.

- `Mmentum.Tools.Tool` defines the callbacks every tool module must implement
- `Mmentum.Tools` owns the explicit list of implemented tool modules and exposes operations to list and invoke them
- Tool names map only to modules already present in that explicit list; request values never become modules or atoms

The behaviour will define callbacks for:

- Tool name and description
- Input and output schemas
- Optional MCP annotations
- Required authorization scope
- Execution

A tool execution receives `Context.t()` containing `User.t()`, verified `Scope.t()` permissions (`:read` or `:write`), and a single `DateTime.t()` instant. The transport maps recognized OAuth scope strings to these permissions; unrelated scopes grant no tool access. Tools never accept the caller's identity from arguments. `Mmentum.Tools` enforces each tool's required scope before execution.

Tool execution returns `{:ok, result}` or `{:error, reason, client_safe_message}`. Unknown tool names return `{:error, :tool_not_found}` from the registry. Each MCP version formats successful results as structured content plus JSON text and execution failures as `isError` tool results.

The implemented tool modules are:

- `Mmentum.Tools.ListHabits`
- `Mmentum.Tools.GetHabit`
- `Mmentum.Tools.CreateHabit`
- `Mmentum.Tools.UpdateHabit`
- `Mmentum.Tools.ManageHabitCompletions`

The embedded agent includes these tool modules in its agent context in the same way as any other agent tool. It does not need a separate embedded-agent registry or an HTTP call back into Phoenix.

### MCP transport

- `router.ex` mounts `/mcp` with `forward`, following EMCP's router shape. The endpoint skips its normal body parser for this scope but does not bypass the router
- `Mmentum.MCP.Transport.StreamableHTTP` checks HTTP content types and Origin, bounds and decodes the body, and sends the selected implementation's response
- `Mmentum.MCP.Versions` owns the version registry and selection. `initialize` selects the older implementation; explicit per-request protocol metadata selects the newer rules, even if a conflicting header claims the older version. Otherwise the HTTP version header selects the implementation. Missing, repeated, and unknown versions are rejected rather than retried as older requests
- Each namespace under `Mmentum.MCP.Versions.V2025_11_25` and `V2026_07_28` contains `Request`, `Server`, and `Response`: validation, operation dispatch, and message formatting respectively. They do not depend on each other or receive `Plug.Conn`
- Both servers call `Mmentum.Tools` directly. There is no shared server that branches on protocol version
- OAuth authentication runs in a dedicated MCP router pipeline before the transport. Do not register real tools before scopes and tool validation are ready

The remote request flow is:

`MCP client -> router authentication -> HTTP transport -> version selection -> version server -> Mmentum.Tools -> application boundary`

To retire the older version, delete its namespace and tests, remove its registry entry and `initialize` selection clause, and update client setup guidance. The modern server derives advertised versions from the registry; its implementation and the application tools need no changes.

## Implemented behavior

- Route stateless Streamable HTTP POST requests through the Phoenix router, leaving their bodies for the transport to parse
- Require `application/json` requests and acceptance of JSON and SSE responses for both versions
- Allow absent Origin headers for non-browser clients and reject browser origins outside the configured application origin
- For `2026-07-28`, require per-request metadata and matching version, method, and applicable name headers
- For `2025-11-25`, validate initialization and require the agreed version header on later requests; modern metadata and routing headers are not required
- Implement `server/discover` with the server identity, supported version, and tools capability
- Implement `tools/list` and `tools/call` against the registered `Mmentum.Tools` catalog
- Return modern result metadata and cache hints only for `2026-07-28`; use the older initialization and result shapes for `2025-11-25`
- Return HTTP 405 for GET and DELETE; neither implementation opens a server-to-client stream or issues session IDs

`list_habits` accepts an empty argument object and requires `mmentum:read`. It calls `Habits.list_habits_with_current_progress/2` using the user's local time and passes the loaded habits to `HabitValue.build/1`. It returns `{time_zone: "...", habits: [...]}` with `id`, `name`, `identity`, `why_it_matters`, `what_counts`, `periodicity`, `min_completions`, `max_completions`, and uncapped `current_completions` per habit. No habits is a successful empty list.

`get_habit` requires `habit_id` and `mmentum:read`. By default it returns the habit's definition, current progress, and completion entries from the current and previous habit periods. `history` defaults to `"recent_periods"`; use `"all"` to also get a page of complete history. Missing habits and habits belonging to another user return the same not-found error.

`create_habit` requires `mmentum:write` and accepts writable fields directly: `name` and `min_completions` are required; `periodicity` defaults to `week`. Optional fields are `identity`, `why_it_matters`, `what_counts`, and `max_completions`. It calls `Habits.create_habit/2`; the authenticated user supplies ownership. Repeating a successful call creates another habit; the tool advertises that it is not idempotent.

`update_habit` requires `mmentum:write` and accepts `{habit_id: integer, fields: {...}}`. It calls the existing ownership-scoped, row-locked `Habits.update_habit/3`. Omitted fields retain stored values; explicit null clears optional fields. An empty fields object is a no-op. Current progress uses the updated periodicity. Invalid target combinations fail against stored state without writing.

The three single-habit tools include `time_zone` and `habit`, using the same Habit Value schema as the list tool. `get_habit` also returns `current_period`, `previous_period`, and `history`, described below. Each tool builds its own response. `HabitFields` shares writable-field schemas; `Tool` formats Zoi and Ecto validation errors; `Context.current_time/1` uses the user's local time with an `Etc/UTC` fallback. Zoi generates output types and JSON Schema from the same definitions. Tools reject unknown arguments, and domain changesets check business rules. Invalid arguments and failed operations return MCP tool errors rather than JSON-RPC transport errors.

Invalid checked fields return HTTP 400. Unknown methods return a JSON-RPC method-not-found error, with HTTP 404 in the modern version and HTTP 200 in the older version. `clientInfo` is required during older initialization and optional on modern requests. Request IDs must be strings or integers; unreadable IDs are omitted from errors. Accepted notifications return HTTP 202 without a body. Unknown extension fields remain open; unused tracing fields are not interpreted.

Only these two protocol versions are supported. A missing version header after initialization is rejected; the older spec's suggested `2025-03-26` default is not implemented. The separate `2024-11-05` HTTP+SSE transport is also not implemented.

Primary references: [modern messages](https://modelcontextprotocol.io/specification/2026-07-28/basic), [modern HTTP](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http), [older lifecycle](https://modelcontextprotocol.io/specification/2025-11-25/basic/lifecycle), and [older HTTP](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports).

## Habit history

`get_habit` returns both recent periods even when they have no completions. Daily habits cover today and yesterday, weekly habits cover this week and last week, and monthly habits cover this month and last month. Weeks begin on Monday. `Habits.Finders.HabitWithHistory` finds the user's habit and reads the two periods together. It uses `Time` for local calendar boundaries, including daylight-saving changes, and gives `HabitValue` only the current period's entries to calculate progress.

Each period contains `starts_at`, `ends_before`, and `completions`, newest first. The start is included; the next period's start is not. All timestamps are UTC strings, and the outer `time_zone` identifies the user's calendar. The habit's `periodicity` says whether these are days, weeks, or months. Recent periods are returned in full; `list_habits`, create, and update keep their existing response shapes.

For complete history, call `get_habit` with `history: "all"`. The response still includes both recent periods and adds `history: {completions: [...], next_cursor: ...}`. Without this option, `history` is null. `limit` defaults to 50 and must be between 1 and 100. Supply `limit` or `cursor` only with `history: "all"`.

`Logs.list_history_page/4` reads one page using the completion time and ID, both descending. The ID breaks ties when several entries share a timestamp. It reads one extra entry to check whether another page exists. `LogValue` builds completion entries, and the tool builds a cursor with the last returned entry's `completed_at` and `id`. Pass that object unchanged as `cursor` on the next call; a null `next_cursor` means the history is exhausted. The next call does not need to look up the cursor's record, so deleting that entry does not break paging.

Both recent and complete history check the user on the habit and completion records. Cursor fields are checked before database access and never change which habit or user the query reads. Paging reads live records, not a saved snapshot: newly backdated completions can appear on later pages. Complete history includes all stored entries, including future completion times. Current progress always counts only the current local period, even when browsing older entries.

## Completion batches

`manage_habit_completions` requires `mmentum:write`. Supply `add`, `remove`, or both; each supplied list must contain at least one entry. Each addition has a `habit_id` and an optional `completed_at` with a date, time, and UTC offset, such as `2026-10-08T18:30:00-04:00`. If the time is omitted, the tool uses the request's `now` for that entry. The removal list contains completion IDs, which must not repeat.

The tool checks the input and calls `Habits.Services.ManageHabitCompletions` to save the changes. `Logs.Finders.CompletionsById` finds the user's completion entries once, so the Service knows which habits to lock. The Service locks those habits in ID order and indexes the returned records by ID. Every addition must find its habit in that map before it can write. Removals use one database call that returns the deleted entries; the Service looks up every requested ID in those entries. If any entry disappeared while the call waited, its lookup fails and the whole transaction rolls back, including any entries it just removed. A missing habit, missing completion, or entry belonging to another user leaves every completion unchanged. These checks use the actual records, not row counts.

The tool returns `{added: [...], removed: [...]}`. `Logs.Values.Log` builds each entry with `id`, `habit_id`, and `completed_at` in UTC. Both lists keep their request order. Completion time uses the existing `logs.inserted_at` field, which stores whole seconds; `updated_at` records when the database write happened. No migration is needed.

The tool can remove historical completions; dashboard undo still removes only the latest entry in the current period. Future completion times are accepted. Retrying additions creates more completions, and retrying an already-removed ID fails. The tool's annotations tell clients that it can delete entries and that repeating a call may change the result.
