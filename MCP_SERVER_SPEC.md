# MCP Server Specification

## Protocol implementation

Mmentum implements MCP `2026-07-28` with a stateless Phoenix HTTP transport. It currently supports server discovery and an empty tool catalog. Habit tools are planned in [`mcp-tools.md`](mcp-tools.md).

In this protocol version, each request carries its protocol version and client capabilities in `params._meta`. There is no `initialize` exchange or MCP session to remember them. `server/discover` reports what the server supports; clients can also send an operation directly. OAuth grants and browser login sessions still exist independently of MCP requests.

The official specification defines the contract. [`EMCP`](https://github.com/PJUllrich/emcp) supplied implementation examples, but its older initialization and session handling do not apply here.

Design decisions:

- Target MCP `2026-07-28`
- Implement protocol features when they improve or enable the user experience
- Keep tool definitions and executors independent from the HTTP transport
- Validate the implementation with MCP Inspector and supported clients
- Add `2025-11-25` compatibility only if an important client requires it
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

OpenCode and Pi default to the older `initialize` flow; set the version explicitly. Configure a public client ID, requested scopes, and the exact registered callback address. Public clients need no client secret. A URL alone is insufficient because the server does not register clients automatically.

Local OAuth requires HTTPS. Use the existing `OAUTH_DEV_TLS_CERTFILE` and `OAUTH_DEV_TLS_KEYFILE` settings with a locally trusted certificate, and set `OAUTH_ISSUER` to that HTTPS origin. Keep certificate and key files outside the checkout. The ordinary HTTP development server alone is insufficient for this flow.

Current Claude Code, Claude, ChatGPT, Codex, and OMP remain unverified. These results establish the tested flows, not complete protocol conformance. Test a current Claude Code release before deciding whether to add support for older requests.

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
- `Mmentum.MCP.Transport.StreamableHTTP` parses JSON and checks the request envelope, required metadata, known client capability shapes, client details, log level, progress token, and pagination cursor type before comparing routing headers and dispatching. Unknown extension fields remain open; unused tracing fields are not interpreted
- `Mmentum.MCP.Server` handles MCP operations such as discovering the server and listing tools. It receives validated requests and returns results or named failures, without handling HTTP
- `Mmentum.MCP.JSONRPC` builds JSON-RPC replies and maps named errors to numeric codes. The transport chooses HTTP status codes
- OAuth authentication runs in a dedicated MCP router pipeline before the transport. Do not register real tools before scopes and tool validation are ready

The remote request flow is:

`MCP client -> router MCP scope/authentication -> Streamable HTTP Plug -> MCP server -> Mmentum.Tools -> tool module -> application boundary`

## Implemented behavior

- Route stateless Streamable HTTP POST requests through the Phoenix router, leaving their bodies for the transport to parse
- Require protocol and method headers, the name header for named operations, the `application/json` content type, and acceptance of JSON and SSE responses
- Allow absent Origin headers for non-browser clients and reject browser origins outside the configured application origin
- Check that routing headers match the JSON-RPC body
- Implement `server/discover` with the server identity, supported version, and tools capability
- Implement `tools/list` against the real, currently empty `Mmentum.Tools` catalog
- Leave `tools/call` unavailable until the first real tool; do not invent execution or tool-error handling ahead of that work
- Return `resultType`, server metadata, cache hints, and standard JSON-RPC errors
- Reject legacy GET and DELETE transport requests

There are no habit tools or `tools/call` implementation yet. Tool argument/output validation and per-tool scope enforcement belong with the first real tool. Add each tool as a small complete change; do not introduce fake tools to test the registry. James will design and write the application implementation behind each tool.

The transport returns HTTP 400 for invalid checked fields and header errors, and HTTP 404 for unknown methods. `clientInfo` is optional. Request IDs must be strings or integers; error responses omit the ID when it cannot be read. No notification operation is implemented; unknown notifications receive HTTP 202 with no response body. Encoded name headers are decoded before comparison.

Primary references: [MCP messages and metadata](https://modelcontextprotocol.io/specification/2026-07-28/basic) and [Streamable HTTP](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http). EMCP provides implementation examples, not the authority for this protocol version.

## Deferred until later slices

- Confirm protocol and OAuth compatibility with ChatGPT and the remaining target clients
- Choose JSON Schema validation for tool arguments and results
- Define client-safe messages for real tool execution errors
- Define the execution context from the needs of the first real tool
