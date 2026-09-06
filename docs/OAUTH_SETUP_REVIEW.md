# OAuth setup and review guide

Mmentum's MCP endpoint uses AttestoPhoenix for OAuth 2.1 authorization-code + PKCE and AttestoMCP for bearer validation. The implementation is custom to this app; it does not use an MCP SDK or add product/fake tools.

## Configured public clients

Clients are static and pre-registered through `OAUTH_PUBLIC_CLIENTS_JSON` at runtime. Each entry must be a JSON object with:

```json
{"id":"client-id","name":"Client name","redirect_uris":["https://client.example/callback"]}
```

Rules enforced at startup:

- `id` is 1-255 bytes, unique, and must not contain `:`
- `name` is 1-100 bytes
- `redirect_uris` is non-empty
- redirect URIs must be HTTPS, except IP-loopback HTTP on `127.0.0.1` or `[::1]`
- all clients are public clients; client secrets are not accepted

Test config includes only `oauth-test` with redirect URI `https://client.example/callback`. Development and production have no usable client unless `OAUTH_PUBLIC_CLIENTS_JSON` is set.

## Local HTTPS setup

OAuth routes require HTTPS even in development. The default non-production issuer is `https://localhost:4443`; the MCP audience/canonical resource URL is always `#{OAUTH_ISSUER}/mcp`.

One local pattern:

```sh
mkcert localhost 127.0.0.1 ::1
export OAUTH_ISSUER=https://localhost:4443
export OAUTH_DEV_TLS_CERTFILE="$PWD/localhost+2.pem"
export OAUTH_DEV_TLS_KEYFILE="$PWD/localhost+2-key.pem"
export OAUTH_PUBLIC_CLIENTS_JSON='[{"id":"local-client","name":"Local client","redirect_uris":["http://127.0.0.1:6274/oauth/callback"]}]'
mix setup
mix phx.server
```

For repeatable local tokens across restarts, set a stable development signing key instead of relying on the generated in-memory key:

```sh
openssl ecparam -name prime256v1 -genkey -noout -out oauth-signing-key.pem
export OAUTH_SIGNING_PRIVATE_KEY_PEM="$(cat oauth-signing-key.pem)"
```

Do not commit local certificates, private signing keys, production hostnames, or one-off client registrations.

## Production runtime env names

OAuth-specific env names:

- `OAUTH_ISSUER` - required in production; HTTPS origin only, no path, query, fragment, userinfo, or trailing slash
- `OAUTH_SIGNING_PRIVATE_KEY_PEM` - required in production; private signing key PEM
- `OAUTH_PUBLIC_CLIENTS_JSON` - static public-client registrations; omit only if no clients should connect
- `OAUTH_TRUSTED_PROXIES_JSON` - optional JSON list passed to Attesto request context

Existing production env remains required as before, including `DATABASE_URL`, `SECRET_KEY_BASE`, and deployment host/port settings such as `PHX_HOST`, `PORT`, `POOL_SIZE`, `ECTO_IPV6`, and `PHX_SERVER` where applicable.

Startup safety checks reject insecure issuers, malformed clients, duplicate client IDs, client secrets, and missing production signing material. There is no local authentication bypass.

## Routes and scopes

Discovery and key routes:

- `GET /.well-known/oauth-authorization-server`
- `GET /.well-known/oauth-protected-resource/mcp`
- `GET /.well-known/jwks.json`

OAuth routes:

- `GET /oauth/authorize` - browser session required; only authorization-code requests with query response mode are accepted
- `POST /oauth/consent` - browser-owned allow/deny decision for the signed authorization request
- `POST /oauth/token` - public-client authorization-code and refresh-token exchange

MCP resource route:

- `/mcp` - protected by AttestoMCP bearer validation, exact resource audience `#{OAUTH_ISSUER}/mcp`, and `mmentum:read`

Supported scopes are `mmentum:read` and `mmentum:write`. The current MCP route requires `mmentum:read`; no product tools are registered yet.

## Connected-app disconnect

Users can review and disconnect clients at `GET /users/connections`. Disconnect uses `DELETE /users/connections/:id` from the browser UI. It marks the Mmentum connection revoked and revokes any known Attesto refresh-token family and authorization-code access-token descendants. Already issued JWTs are also rejected by Mmentum's protected-resource principal check after disconnect.

The AttestoPhoenix `/oauth/revoke` endpoint still rejects public clients in the pinned release, so browser-owned Disconnect is the supported revocation path for this slice.

## Required package tables

The OAuth slice requires both new migrations:

- `20260906023635_create_attesto_phoenix_tables.exs` creates Attesto Ecto store tables for authorization codes, refresh tokens, refresh family revocations, consent grants, and the other package-backed grant tables expected by AttestoPhoenix. Some package tables are unused by this app today but are required by the library-backed store set.
- `20260906023636_create_oauth_connections.exs` creates Mmentum's app-owned `oauth_connections` table linking a user, static client ID, Attesto grant/refresh family, scopes, and disconnect state.

Rollback drops these tables and removes outstanding authorization codes, refresh tokens, consent grants, revocation tombstones, and connection records. In production, that would disconnect OAuth clients and invalidate/revoke recovery state; validate rollback only on local or disposable databases unless explicitly approved.

## Deferred checks and known gaps

- Real MCP client/browser checks remain deferred; do not claim independent client compatibility from server-side tests alone.
- AttestoPhoenix public-client `/oauth/revoke` remains a known limitation; use Connected apps Disconnect.
- `mix hex.audit` reports pre-existing advisories in Bandit, Postgrex, Phoenix LiveView, and Mint. This OAuth delivery did not widen scope to dependency remediation.
