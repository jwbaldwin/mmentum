# MCP client setup

Open **Connected apps → Connect an AI app**, choose your client, and copy the setup prompt into your agent. It contains the registered configuration, browser sign-in instructions, and a read-only `list_habits` check. You still approve access in your browser. The setup page is `/users/connections/new` and requires a Mmentum login.

The prompt is self-contained: the agent does not need a Mmentum session to read setup instructions. It includes only public configuration, never credentials. Cursor and VS Code also offer direct installation. Detailed manual instructions and troubleshooting stay collapsed until needed. Hosted clients that cannot use an agent-edited config retain their manual flow.

Client marks use official publisher assets, shared by setup, consent, and Connected apps. Sources and usage limits are recorded in [`priv/static/images/mcp-clients/README.md`](../priv/static/images/mcp-clients/README.md). ChatGPT and Codex share the official OpenAI Blossom; Codex's extension uses this mark. James reviewed Anthropic's terms and approved this integration's logo use on October 9, 2026.

The client list builds on PlanetScale's choices: Cursor, VS Code, Claude Code, Claude web/desktop, OpenCode, Codex CLI, ChatGPT, Antigravity CLI, Gemini CLI, Amp CLI, Notion Custom Agents, Pi, and other remote clients. Claude Managed Agents was removed at James's request.

## Code ownership

`MmentumWeb.MCPClientGuides` keeps the ordered client catalog and client-specific instruction clauses together. Its `Client` structs contain each key, display name, and light/dark logo filenames. Setup, consent, and Connected apps all resolve logos through this catalog; there is no second image registry.

`build/3` returns a `Guide` containing ordered `Step` structs. Its state is `:ready`, `:registration_required`, `:callback_required`, or `:manual_oauth_required`. Each callback-sensitive clause selects its state when building the configuration; the template does not infer readiness from missing step text. A missing registration takes precedence over other prerequisites. Agent-assisted guides put installation and authentication first, and a ready guide builds its prompt from those steps. Manual guides never gain an agent prompt just because they contain a client ID.

`MCPSetupLive` selects a known client from the URL, loads its mapped registration, and passes it to the catalog. One HEEx template renders every guide. These are web presentation structs, not new authentication or domain boundaries; they do not register clients or validate tokens.

Desktop uses a grid of labeled client marks. Mobile keeps a native select with the selected client's mark inside the control; the mark updates from the same server-owned client selection. It is decorative and ignores pointer events, so it does not intercept taps or replace the select's native keyboard behavior. The heading supplies the accessible label. Other clients uses the generic link icon.

Successful pointer-triggered copies show a brief orange edge glow: two highlights leave the bottom-left together and meet at the top-right. `CopyText` measures the copied block or prompt button, animates two equal-length SVG paths for 720 ms, and cancels them on retry, client change, or hook destruction. The prompt button reserves its label width so confirmation does not move adjacent controls. Keyboard and reduced-motion users get the same immediate text and screen-reader confirmation without the sweep. Failed copies retain the manual-copy fallback and never show the success glow.

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
- **Antigravity CLI (`antigravity`):** documented callback `https://antigravity.google/oauth-callback`. Global configuration lives in `~/.gemini/config/mcp_config.json`, or `.agents/mcp_config.json` for a project; remote entries use `serverUrl`, not Gemini CLI's `httpUrl`. In `agy`, `/mcp` opens the manager and its Authenticate action. The guide remains manual even with a mapped registration: Google's manual OAuth example includes a secret, whereas Mmentum's clients are public. It does not generate a secret, copyable OAuth configuration, or agent setup prompt. Mapping a registration alone does not resolve this client-side OAuth requirement.
- **Gemini CLI (`gemini`):** a fixed `http://localhost:PORT/oauth/callback`. Google retains Gemini CLI for enterprise and paid API access; consumer accounts use Antigravity CLI.
- **Amp CLI (`amp`):** register `http://localhost:8976/oauth/callback` for manual OAuth setup.
- **Notion Custom Agents (`notion`):** arrange pre-registration with Notion. Its Custom Agents flow does not document an arbitrary user-supplied client ID. A URL alone cannot connect it to this server.
- **ChatGPT (`chatgpt`):** copy the exact redirect URI from the MCP server's management page in ChatGPT. Callback-specific and stable redirect modes exist; do not substitute a universal callback. Use OAuth with the pre-registered public client ID, not CIMD or DCR.
- **Pi (`pi`):** the guide targets native MCP introduced in Pi 0.99, without the `pi-mcp-adapter` extension. The [0.99 guide](https://github.com/earendil-works/pi/blob/v0.99.0/packages/coding-agent/docs/mcp.md) documents the same public-client and callback settings used here. Register a fixed HTTP callback on `localhost`, `127.0.0.1`, or `::1`, including an explicit nonzero port other than 80 and no query parameters. Pi normalizes port 80 and rejects query-bearing callbacks. Generated `oauth.callbackUrl` preserves the exact URI in `~/.pi/agent/mcp.json`; login uses `pi mcp login mmentum`. A missing or unsuitable callback withholds the configuration and agent prompt.
- **Other (`other`):** requires Streamable HTTP and pre-registered public OAuth support, with an exactly registered callback.

OpenCode, Claude Code, Gemini, and Pi snippets are withheld if the registration lacks their supported loopback callback shape. Claude Code also requires a callback without query parameters, since its port-only setting cannot reproduce them. The page shows a callback correction message instead.

Scope configuration requests `mmentum:read` where the client exposes that setting. VS Code and Claude connectors do not expose a documented override, and Codex can prefer the server's advertised scopes. The approval page always shows the actual requested permissions. Write tools are not currently available.

Native Pi starts with the configured read scope but can add scopes requested by an authentication challenge; review the actual consent. Older `pi-mcp-adapter` setups use `oauth.redirectUri` and `/mcp-auth` instead of native Pi's settings and commands.

`claude-managed-agents` is no longer a setup key. If an existing registration uses it, remove its optional `setup_client` field before restarting; the registration itself can remain valid and no grant is revoked by removing a guide.

## Approval and management

Consent keeps the existing signed request, CSRF protection, one-use approval, and client redirect. It leads with the requesting app's logo pointing to Mmentum's logo, followed by a compact account and permission panel. The heading names the requesting app and Mmentum in text as well. Authorize access and Cancel sit below; the callback and server details remain available in a disclosure. Hidden inputs render without layout wrappers so they cannot offset the actions.

Connected apps shows only the current user's active grants. A grant awaiting token exchange is **Setup unfinished**; a completed exchange is **Access approved**, not proof that the app is online. Names come from configured client registrations, with the stored client ID retained when a registration has been removed. Approval dates are shown in UTC.

Disconnect requires an explicit confirmation action. The existing domain operation revokes the grant and its token family; the page then redirects with feedback. This leaves habits and client-side server configuration unchanged.

## Verification boundary

The setup's first prompt asks the client to call `list_habits`. An authenticated empty result is valid. The app does not record last-use or connection-health evidence and does not mark a client verified when someone copies configuration or approves access.

Client documentation evolves independently. The guides reflect October 2026 sources, linked from each client panel. Compatibility checks in `MCP_SERVER_SPEC.md` remain the record of actual tested clients.

`mix check` includes the clipboard-hook checks, which can also run with `node --test test/js/copy_text_test.mjs`. LiveView/controller tests do not execute JavaScript. A real browser check remains necessary for copying, responsive layout, themes, and the approval/Disconnect interactions.
