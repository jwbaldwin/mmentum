# MCP client setup

Open **Connected apps → Connect an AI app** to choose a client, add the server, approve access, and try a read-only habit query. The setup page is `/users/connections/new` and requires a Mmentum login.

The client list follows PlanetScale: Cursor, VS Code, Claude Code, OpenCode, Codex CLI, Claude web/desktop, Gemini CLI, Amp CLI, Notion, Claude Managed Agents, and other remote clients. These are setup guides, not a claim that every client has passed end-to-end compatibility testing.

## Link an existing registration to its guide

Mmentum still accepts only pre-registered public OAuth clients. Add the optional `setup_client` field to an existing entry in `OAUTH_PUBLIC_CLIENTS_JSON` to make its public configuration available on the corresponding setup page:

```json
[
  {
    "id": "mmentum-cursor",
    "name": "Cursor",
    "setup_client": "cursor",
    "redirect_uris": ["http://localhost:8787/callback"]
  },
  {
    "id": "mmentum-opencode",
    "name": "OpenCode",
    "setup_client": "opencode",
    "redirect_uris": ["http://127.0.0.1:19876/callback"]
  }
]
```

Each setup key must identify a known guide and appear only once. Mapped registrations require a public ID, display name, and at least one redirect URI. Existing registrations without a setup key still authorize and appear in Connected apps; the setup page does not guess which guide they belong to.

The page builds snippets from the configured MCP audience, public client ID, and registered callback. It never reveals tokens or creates registrations. Cursor and VS Code have install links containing public configuration only. Other clients receive native instructions. When no registration is mapped, the page explains the prerequisite and does not invent a client ID or offer a credentialed install link.

## Callback requirements

- **Cursor (`cursor`):** desktop uses `http://localhost:8787/callback`; web agents use `https://www.cursor.com/agents/mcp/oauth/callback`.
- **VS Code (`vscode`):** register the exact callback from the installed desktop/hosted surface. The guide does not invent a scope or callback override that its configuration does not support.
- **Claude Code (`claude-code`):** a fixed `http://localhost:PORT/callback`. The command includes that port. Some earlier versions used `127.0.0.1` instead.
- **OpenCode V2 (`opencode`):** a fixed `http://127.0.0.1:PORT/callback`. The generated `mcp.servers` configuration includes the exact redirect and callback port.
- **Codex CLI (`codex`):** register the exact callback printed by `codex mcp add` with a public client ID. It may include an endpoint-specific path. The guide uses the registration's first callback; put the Codex callback first.
- **Claude web/desktop (`claude`):** `https://claude.ai/api/mcp/auth_callback`. Use a remote custom connector and its own-client OAuth option.
- **Gemini CLI (`gemini`):** a fixed `http://localhost:PORT/oauth/callback`.
- **Amp CLI (`amp`):** documentation names `http://localhost:8976/oauth/callback`, but its public-client/no-secret login still needs verification.
- **Notion (`notion`):** arrange pre-registration with Notion. Its Custom Agents flow does not document an arbitrary user-supplied client ID. A URL alone cannot connect it to this server.
- **Claude Managed Agents (`claude-managed-agents`):** verify initial public-client authorization and its callback before mapping a registration. Public-client token refresh support does not prove the browser setup flow.
- **Other (`other`):** requires Streamable HTTP and pre-registered public OAuth support, with an exactly registered callback.

OpenCode, Claude Code, and Gemini snippets are withheld if the registration lacks their documented loopback callback shape. Claude Code also requires a callback without query parameters, since its port-only setting cannot reproduce them. The page shows a callback correction message instead.

Scope configuration requests `mmentum:read` where the client exposes that setting. VS Code and Claude connectors do not expose a documented override, and Codex can prefer the server's advertised scopes. The approval page always shows the actual requested permissions. Write tools are not currently available.

## Approval and management

Consent keeps the existing signed request, CSRF protection, one-use approval, and client redirect. It shows the Mmentum account, requested permissions, return destination, and Allow access/Cancel actions.

Connected apps shows only the current user's active grants. A grant awaiting token exchange is **Setup unfinished**; a completed exchange is **Access approved**, not proof that the app is online. Names come from configured client registrations, with the stored client ID retained when a registration has been removed. Approval dates are shown in UTC.

Disconnect requires an explicit confirmation action. The existing domain operation revokes the grant and its token family; the page then redirects with feedback. This leaves habits and client-side server configuration unchanged.

## Verification boundary

The setup's first prompt asks the client to call `list_habits`. An authenticated empty result is valid. The app does not record last-use or connection-health evidence and does not mark a client verified when someone copies configuration or approves access.

Client documentation evolves independently. The guides reflect October 2026 sources, linked from each client panel. Compatibility checks in `MCP_SERVER_SPEC.md` remain the record of actual tested clients.

`mix check` includes the clipboard-hook checks, which can also run with `node --test test/js/copy_text_test.mjs`. LiveView/controller tests do not execute JavaScript. A real browser check remains necessary for copying, responsive layout, themes, and the approval/Disconnect interactions.
