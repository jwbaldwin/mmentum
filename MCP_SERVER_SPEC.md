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

Prove both libraries in a focused integration spike before adopting them. The [first integration check](docs/ATTESTO_INTEGRATION_CHECK.md) found that AttestoPhoenix 3.2.1 rejects public clients at its revocation endpoint. Adoption is paused until we resolve that gap; OAuth is not yet wired into Mmentum.

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

- `router.ex` mounts `/mcp` with `forward`, following EMCP's router shape. The endpoint skips its normal body parser for this scope but does not bypass the router
- `Mmentum.MCP.Transport.StreamableHTTP` reads MCP requests from HTTP, checks that they are valid, and writes HTTP replies. It validates messages once before comparing headers and calling the server
- `Mmentum.MCP.Server` handles MCP operations such as discovering the server and listing tools. It receives validated requests and returns results or named failures, without handling HTTP
- `Mmentum.MCP.JSONRPC` builds JSON-RPC replies and maps named errors to numeric codes. The transport chooses HTTP status codes
- OAuth authentication will run in a dedicated MCP router pipeline before the transport. Do not register real tools before authentication, scopes, and tool validation are ready

The remote request flow is:

`MCP client -> router MCP scope/authentication -> Streamable HTTP Plug -> MCP server -> Mmentum.Tools -> tool module -> application boundary`

## First implementation slice

The first slice creates only:

- The Phoenix MCP scope and empty Streamable HTTP Plug boundary
- `Mmentum.Tools`
- The `Mmentum.Tools.Tool` behaviour
- Tests proving the empty tool catalog and reserved MCP endpoint behave as expected

Do not add a fake tool solely to test the behaviour. Implement and test the behaviour with the first real habit tool. Add each real tool later as its own vertical slice. James will design and write the application implementation behind each tool when that slice begins.

## Second implementation slice

Build the smallest useful MCP `2026-07-28` protocol path without adding a product tool:

- Route stateless Streamable HTTP POST requests through the Phoenix router, leaving their bodies for the transport to parse
- Require the protocol, method, name, exact content type, and accepted response headers defined by the MCP specification
- Allow absent Origin headers for non-browser clients and reject browser origins outside the configured application origin
- Check that routing headers match the JSON-RPC body
- Implement `server/discover` with the server identity, supported version, and tools capability
- Implement `tools/list` against the real, currently empty `Mmentum.Tools` catalog
- Leave `tools/call` unavailable until the first real tool; do not invent execution or tool-error handling ahead of that work
- Return `resultType`, server metadata, cache hints, and standard JSON-RPC errors
- Reject legacy GET and DELETE transport requests

Keep OAuth, full JSON Schema validation, and the seven tools in later slices. This slice builds the stateless protocol boundary; client compatibility remains unverified.

The transport returns HTTP 400 for malformed request metadata and header errors, and HTTP 404 for unknown methods. `clientInfo` is optional. Request IDs must be strings or integers; notifications have no ID. Encoded name headers are decoded before comparison.

Primary references: [MCP messages and metadata](https://modelcontextprotocol.io/specification/2026-07-28/basic) and [Streamable HTTP](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http). EMCP provides implementation examples, not the authority for this protocol version.

## Deferred until implementation spikes

- Confirm real client support for MCP `2026-07-28`
- Confirm Attesto's Phoenix session integration, refresh-token behavior, and generated persistence
- Choose the JSON Schema validation mechanism
- Define client-safe messages for real tool execution errors
- Define the execution context from the needs of the first real tool
