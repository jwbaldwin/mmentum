# MCP usage logs

Authenticated, JSON-decoded MCP requests emit one `mcp_request_completed` info log
after protocol dispatch. Both supported protocol versions use the same transport
boundary. Duration is dispatch time in monotonic microseconds, including request
validation, tool execution and response construction, but not HTTP transmission.

Fields:

- `mcp_method`: a supported method, `notification`, or `unknown`
- `mcp_tool`: a registered tool name, `unknown` for an unrecognized/malformed tool call, or `none`
- `mcp_client`: the registered client's bounded `setup_client` key, or `unknown`
- `mcp_protocol`: the selected supported protocol version
- `mcp_outcome`: `success`, `tool_error`, `protocol_error`, `notification`, or `exception`
- `mcp_duration_us`: elapsed microseconds

Tool results with `isError: true` count as `tool_error` even when HTTP status is
200. JSON-RPC errors count as `protocol_error`. Exceptions, throws and exits emit
`exception` and propagate unchanged, including their original stacktrace.

Client attribution comes only from verified access-token claims mapped to the
server's registered OAuth clients. It identifies the registration, not a verified
software installation. Client-supplied `clientInfo` is never used. Missing,
unmapped or unsupported setup keys become `unknown`; the bounded key list lives
in `Mmentum.MCP.Usage`, independent of web setup instructions.

These events contain no user/connection IDs, request arguments, results, habit
content, token values, email addresses, raw client IDs/names, unknown method/tool
names, or exception details. Existing HTTP request IDs remain available through
the standard logger configuration. This is not an audit trail or unique-user
counter: retention depends on existing log collection. Authentication failures,
HTTP validation failures and bodies rejected before JSON decoding do not emit a
usage event. Framework crash logging remains separate from these safe events.

No database writes, metrics backend, dashboard or OAuth lifecycle tracking is
added. Revisit persistent aggregation only when log retention or analysis needs
justify it; the shared transport dispatch is the extension point.
