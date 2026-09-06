# Attesto integration check

## Decision: pause adoption

Checked `attesto_phoenix 3.2.1`, `attesto_mcp 1.3.0`, and `attesto 2.0.1` on 2026-09-05.

The token exchange and MCP scope checks work together, but the bundled revocation endpoint rejects public clients. Resolve this before wiring OAuth into Mmentum. No authentication pipeline, OAuth routes, migrations, signing keys, or application dependencies have been added.

The MCP endpoint remains unauthenticated with an empty catalog and no tool execution. Do not expose real tools in this state.

## Reproduce

```sh
elixir scripts/spikes/attesto_public_client.exs
```

This standalone ExUnit check installs pinned Attesto versions outside Mmentum's dependency graph. It generates a temporary signing key, uses supervised library ETS stores, and calls the real token and revocation controllers through Plug connections. It also calls the real MCP authentication and scope plugs. It does not start Mmentum or touch a database.

The check intentionally asserts the behavior we need, so it currently exits with code 2:

```text
PASS: public client exchanges its PKCE-bound code
PASS: attesto_mcp accepts the token for reads and rejects writes
PASS: public client refreshes and rotates its refresh token
Revocation response: HTTP 401 {"error":"invalid_client","error_description":"client authentication failed"}
Refresh after attempted revocation: HTTP 200
```

The client supplies `client_id` and its own refresh token to `/oauth/revoke`. It has no client secret, as expected for a public PKCE client. The same client succeeds at `/oauth/token` before and after the failed revocation.

This is a library compatibility check, not an end-to-end Mmentum authentication test. The check issues the authorization code through the library primitive; it does not exercise browser login or consent.

## Why revocation fails

In the released `attesto_phoenix` source:

- `AttestoPhoenix.ClientAuthentication.Policy.for_endpoint/2` allows only `client_secret_basic` and `client_secret_post` for revocation
- `AttestoPhoenix.Controller.RevocationController` uses that fixed policy, not the token endpoint's configured authentication-method allowlist
- Setting `token_endpoint_auth_methods_supported: ["none"]` therefore permits public token exchange but does not permit public revocation

Source: the [released Hex package](https://repo.hex.pm/tarballs/attesto_phoenix-3.2.1.tar), at `lib/attesto_phoenix/client_authentication.ex` and `lib/attesto_phoenix/controller/revocation_controller.ex`.

## Other integration facts

- Attesto delegates login, consent UI, client lookup, user lookup, and scope policy to the host. These are not ready-made screens
- Mmentum currently uses `current_user` and its existing LiveView/session login, not the inherited template's `current_scope` convention
- A host `build_principal/3` callback supplies the token's `kind`, namespaced `sub`, and granted `scopes`
- Refresh-token issuance requires an explicit policy callback or `offline_access`. Our two product scopes alone do not trigger the default refresh policy
- The Ecto refresh store requires a stable runtime secret for encrypted retry recovery when using its nonzero rotation grace period
- `attesto_mcp` verifies token claims and scopes but does not automatically inherit Phoenix's code-store revocation checks. The eventual principal callback must reject revoked connections as well as missing users
- Revoking refresh tokens alone does not invalidate already-issued JWTs. The configured `authorization_grant_id_claim` can bind access tokens to a refresh family; Mmentum still needs to check that family's revocation state
- The current MCP authorization specification prefers Client ID Metadata Documents, also permits pre-registration, and deprecates dynamic registration. Client onboarding remains a choice to settle before implementation
- Adopting these releases would require upgrading Mmentum's locked Plug version from 1.20.2 to at least 1.20.3

## Proposed next decision

Prefer an upstream fix for public-client revocation, keeping OAuth HTTP behavior in the library as planned. Alternatively, Mmentum can own a small revocation controller using Attesto's client-authentication and revocation primitives. That adds protocol code we had intended to delegate and needs James's agreement.

Do not work around this by giving a public client a pretend secret or silently omitting revocation.

After that decision, complete the integration with:

1. Existing Phoenix login and request-bound, single-use consent
2. A deliberate client onboarding policy
3. Ecto code, refresh, consent, and revocation stores, with cleanup supervision
4. Runtime signing keys, JWKS, issuer and exact MCP audience configuration
5. MCP router authentication and scope enforcement
6. A user-owned connected-client list and revocation action
7. Endpoint tests for login, consent denial/replay, PKCE failure, refresh rotation/reuse, wrong audience, expired tokens, revoked connections, and read/write scopes

No production deployment or real tool registration belongs in this slice.

## References

- [MCP 2026-07-28 authorization](https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization)
- [AttestoPhoenix 3.2.1](https://hexdocs.pm/attesto_phoenix/3.2.1/readme.html)
- [AttestoMCP 1.3.0](https://hexdocs.pm/attesto_mcp/1.3.0/readme.html)
