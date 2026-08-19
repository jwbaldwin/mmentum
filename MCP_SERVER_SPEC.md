# MCP Server Specification

## Protocol implementation

Mmentum will implement its hosted MCP server as a small, stateless Phoenix transport rather than depend on an Elixir MCP SDK.

There is no officially supported Elixir SDK. The community `mcp_elixir_sdk` package is active but implements MCP `2025-11-25` and does not document support for the newer `2026-07-28` protocol. That newer protocol materially changes the HTTP boundary by removing initialization handshakes, protocol sessions, and GET/SSE session handling in favor of stateless requests.

Use the local [`EMCP`](https://github.com/PJUllrich/emcp) checkout as the main reference implementation. Reuse and adapt as much of its Plug transport, JSON-RPC parsing, errors, schema validation, tool registration, prompts, resources, and tests as remains useful under MCP `2026-07-28`. Do not inherit EMCP's older protocol flow, session model, `Plug.Conn`-coupled tools, or MCP-shaped tool results when those conflict with this specification.

Mmentum will therefore:

- Target MCP `2026-07-28`
- Implement protocol features when they improve or enable the user experience
- Keep tool definitions and executors independent from the HTTP transport
- Validate the implementation with MCP Inspector and supported clients
- Add `2025-11-25` compatibility only if an important client requires it
- Implement OAuth with maintained libraries rather than writing OAuth itself

The initial product tool surface is defined in [`mcp-tools.md`](mcp-tools.md).

## Authorization

Mmentum will use OAuth 2.1 for public client connections.

Use [`attesto_phoenix`](https://github.com/XukuLLC/attesto_phoenix) for authorization, token, discovery, consent, revocation, and JWKS endpoints. Use `attesto_mcp` for MCP protected-resource metadata and bearer-token validation.

The OAuth flow will:

- Reuse Mmentum's existing Phoenix login and user sessions
- Use Authorization Code with PKCE for public MCP clients
- Offer `mmentum:read` and `mmentum:write` scopes
- Issue short-lived access tokens bound to the hosted MCP URL as their audience
- Issue rotating refresh tokens so approved clients can reconnect without sending the user through browser authorization whenever an access token expires
- Map each token subject to one Mmentum user
- Let users review and revoke connected clients
- Store private signing keys in production secrets and publish public keys through JWKS

Prove both libraries in a focused integration spike before adopting them.

Development and test environments may use a config-only local authentication bypass that supplies a chosen local user. Production must refuse to start if this bypass is enabled. Do not build personal access token storage solely to unblock local development.

## Client compatibility

The first compatibility targets are:

- Claude Code
- Claude
- ChatGPT
- Codex
- OpenCode
- Pi
- OMP

Verify which protocol versions these clients use before implementation. This determines whether Mmentum can ship only the stateless `2026-07-28` transport or must also support the older `2025-11-25` handshake.

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

Tool execution returns ordinary Elixir results such as `{:ok, habit_map}` or `{:error, :not_found}`. It does not return JSON-RPC or MCP response structures. This keeps each tool usable by both the embedded agent and MCP. The MCP transport alone converts those results into MCP structured content and protocol errors.

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

- `Mmentum.MCP.Transport.StreamableHTTP` is a Plug that owns HTTP methods, headers, bodies, content negotiation, and responses
- `Mmentum.MCP.Server` validates supported MCP requests, asks `Mmentum.Tools` for definitions or execution, and maps ordinary Elixir results into MCP responses
- OAuth authentication runs in the Phoenix MCP scope before the transport and supplies the authenticated user to tool execution

The remote request flow is:

`MCP client -> MCP scope authentication -> Streamable HTTP Plug -> MCP server -> Mmentum.Tools -> tool module -> application boundary`

## First implementation slice

The first slice creates only:

- The Phoenix MCP scope and empty Streamable HTTP Plug boundary
- `Mmentum.Tools`
- The `Mmentum.Tools.Tool` behaviour
- Tests proving that a conforming tool can be listed and invoked through the shared tool catalog

Do not implement the seven product tools, their Services, Finders, Values, or new product persistence in this slice. Add each real tool later as its own vertical slice. James will design and write the application implementation behind each tool when that slice begins.

## Deferred until implementation spikes

- Confirm real client support for MCP `2026-07-28`
- Confirm Attesto's Phoenix session integration, refresh-token behavior, and generated persistence
- Choose the JSON Schema validation mechanism
- Define exact MCP protocol error codes and client-safe messages
- Define the execution context from the needs of the first real tool
