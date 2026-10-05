# MCP Server Specification

## Protocol implementation

Mmentum supports MCP `2026-07-28` and `2025-11-25` at the same `/mcp` endpoint. It currently supports connection setup and an empty tool catalog. Habit tools are planned in [`mcp-tools.md`](mcp-tools.md).

In `2026-07-28`, each request carries its protocol version and client capabilities in `params._meta`. `server/discover` reports supported versions and features; clients can also send an operation directly.

In `2025-11-25`, clients send `initialize`, receive the supported version and server capabilities, then send `notifications/initialized`. Later requests carry `MCP-Protocol-Version: 2025-11-25`. The server also answers `ping`. It does not issue session IDs or use client capabilities to initiate requests back to the client, so no MCP session store is needed. OAuth grants and browser login sessions remain separate.

The official specification defines each version's contract. [`EMCP`](https://github.com/PJUllrich/emcp) supplied implementation examples.

Design decisions:

- Target MCP `2026-07-28`
- Implement protocol features when they improve or enable the user experience
- Keep tool definitions and executors independent from the HTTP transport
- Validate the implementation with MCP Inspector and supported clients
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

## Client compatibility

Local client checks on September 22, 2026:

- **OpenCode 2.0.12:** login, approval, token exchange, discovery, empty tool listing, refresh after expiry, and Disconnect passed with `protocol: "2026-07-28"`.
- **Pi 0.85.1 / pi-mcp-adapter 2.34.0:** the same flow passed with `protocolVersion: "2026-07-28"`.
- **Claude Code 2.1.170:** login, approval, and token exchange succeeded. Token storage failed in the isolated client setup, so automatic refresh was not verified. A separate valid-bearer test reached our request parser but failed because this build uses the older MCP request format. Disconnect invalidated that bearer.

After adding older-protocol support on October 4, Claude Code 2.1.170 connected over local HTTPS with a supplied OAuth access token: initialization, readiness notification, and empty tool listing succeeded. The installed Pi MCP SDK also connected and listed tools in both protocol modes, including an older-protocol ping. These checks cover message compatibility; they do not resolve Claude's earlier token-storage failure or repeat its browser OAuth flow.

OpenCode and Pi can use the older initialization flow or explicitly select `2026-07-28`. Configure a public client ID, requested scopes, and the exact registered callback address. Public clients need no client secret. A URL alone is insufficient because the server does not register clients automatically.

Local OAuth requires HTTPS. Use the existing `OAUTH_DEV_TLS_CERTFILE` and `OAUTH_DEV_TLS_KEYFILE` settings with a locally trusted certificate, and set `OAUTH_ISSUER` to that HTTPS origin. Keep certificate and key files outside the checkout. The ordinary HTTP development server alone is insufficient for this flow.

Current Claude Code, Claude, ChatGPT, Codex, and OMP remain unverified. These results establish the tested flows, not complete protocol conformance.

## Application shape

The MCP transport and the embedded Mmentum agent will share the same tool modules. Product rules stay in normal application contexts, Services, Finders, and Values rather than in tool definitions or protocol code.

`Mmentum.Tools` is a narrow cross-cutting adapter exception to the normal module taxonomy. It owns the set of tools available to agents without owning the product behavior behind them. `Mmentum.MCP` is a separate transport exception and must not own product behavior.

### Tool interface

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

A tool execution receives server-built context containing the authenticated user rather than accepting `user_id` from its arguments. We will finalize the rest of that context with the first real tool instead of creating a speculative context module now.

Tool execution returns ordinary Elixir results such as `{:ok, habit_map}` or `{:error, :not_found}`. It does not return JSON-RPC or MCP response structures. This keeps each tool usable by both the embedded agent and MCP. Each MCP version formats those results for its client.

The planned tool modules are:

- `Mmentum.Tools.ListHabits`
- `Mmentum.Tools.GetHabit`
- `Mmentum.Tools.CreateHabit`
- `Mmentum.Tools.UpdateHabit`
- `Mmentum.Tools.RecordHabitCompletions`
- `Mmentum.Tools.ListHabitHistory`
- `Mmentum.Tools.RemoveHabitCompletion`

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
- Implement `tools/list` against the real, currently empty `Mmentum.Tools` catalog
- Leave `tools/call` unavailable until the first real tool; do not invent execution or tool-error handling ahead of that work
- Return modern result metadata and cache hints only for `2026-07-28`; use the older initialization and result shapes for `2025-11-25`
- Return HTTP 405 for GET and DELETE; neither implementation opens a server-to-client stream or issues session IDs

There are no habit tools or `tools/call` implementation yet. Tool argument/output validation and per-tool scope enforcement belong with the first real tool. Add each tool as a small complete change; do not introduce fake tools to test the registry. James will design and write the application implementation behind each tool.

Invalid checked fields return HTTP 400. Unknown methods return a JSON-RPC method-not-found error, with HTTP 404 in the modern version and HTTP 200 in the older version. `clientInfo` is required during older initialization and optional on modern requests. Request IDs must be strings or integers; unreadable IDs are omitted from errors. Accepted notifications return HTTP 202 without a body. Unknown extension fields remain open; unused tracing fields are not interpreted.

Only these two protocol versions are supported. A missing version header after initialization is rejected; the older spec's suggested `2025-03-26` default is not implemented. The separate `2024-11-05` HTTP+SSE transport is also not implemented.

Primary references: [modern messages](https://modelcontextprotocol.io/specification/2026-07-28/basic), [modern HTTP](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http), [older lifecycle](https://modelcontextprotocol.io/specification/2025-11-25/basic/lifecycle), and [older HTTP](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports).

## Deferred until later slices

- Confirm protocol and OAuth compatibility with ChatGPT and the remaining target clients
- Choose JSON Schema validation for tool arguments and results
- Define client-safe messages for real tool execution errors
- Define the execution context from the needs of the first real tool
