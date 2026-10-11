# MCP setup research

Research date: October 9, 2026. Recommendations below are proposals, not agreed implementation scope.

Agreed after research: PlanetScale is the primary UX reference and Mmentum's existing styles stay unchanged. Its client list was the starting point; James later requested removing Claude Managed Agents and adding ChatGPT and Pi. The implementation and registration requirements are documented in [`MCP_SETUP.md`](MCP_SETUP.md). The recommendations below retain the original research context.

## Client-list follow-up

ChatGPT's current official [custom MCP guide](https://developers.openai.com/api/docs/guides/custom-mcp-server.md) uses Plugins → Add custom MCP server, OAuth configuration, then installation and selection with `@`. This replaces the older developer-mode settings path. Its [authentication guide](https://developers.openai.com/plugins/build/auth.md) documents predefined clients as well as CIMD/DCR. Callback addresses can be connection-specific or stable; register the exact URI shown in ChatGPT rather than assume one shared callback. Mmentum's guide exposes only an already-registered public ID and keeps real-client verification outstanding. No registration protocol or server authorization behavior changes.

Pi's [version-pinned native MCP guide](https://github.com/earendil-works/pi/blob/v1.1.0/packages/coding-agent/docs/mcp.md) documents built-in Streamable HTTP, `~/.pi/agent/mcp.json`, public `oauth.clientId`, optional secrets, exact `oauth.callbackUrl`, and `pi mcp login`. The [native flow](https://github.com/earendil-works/pi/blob/v1.1.0/packages/mcp/src/oauth/flow.ts#L349-L353) gives the configured scope precedence over metadata, but [authentication challenges can add scopes](https://github.com/earendil-works/pi/blob/v1.1.0/packages/coding-agent/src/extensions/mcp/oauth.ts#L527-L532). An installed extension registering `/mcp` replaces native MCP in sessions, so the guide explicitly requires Pi 1.1 or later without `pi-mcp-adapter`. Existing local OAuth evidence covers the older adapter, not this native flow. Setup withholds snippets unless an exact, fixed-port HTTP loopback callback is registered: port 80 is normalized, port zero cannot receive the redirect, and query parameters fail native validation. The Pi mark comes unchanged from the publisher's `https://pi.dev/logo-auto.svg`.

### October 10 follow-up

The [Pi 0.99 guide](https://github.com/earendil-works/pi/blob/v0.99.0/packages/coding-agent/docs/mcp.md) already documents native MCP with `oauth.clientId`, optional secrets, `scope`, `callbackUrl` and `pi mcp login`. Its [callback implementation](https://github.com/earendil-works/pi/blob/v0.99.0/packages/coding-agent/src/extensions/mcp/oauth.ts) has the same fixed-port preservation and default-port normalization. The UI now says Pi 0.99 or later, instead of imposing the later 1.1 floor; the adapter remains excluded.

Publisher naming supports OpenCode, Pi, Codex CLI, and Amp CLI as written. Notion's guide targets [Custom Agents](https://www.notion.com/help/mcp-connections-for-custom-agents), so the UI identifies that surface. Google's [transition announcement](https://developers.googleblog.com/an-important-update-transitioning-gemini-cli-to-antigravity-cli) retains Gemini CLI for enterprise and paid API access, while consumers moved to Antigravity CLI on June 18, 2026. These are separate clients and configurations, not interchangeable labels.

Antigravity's current [MCP docs](https://antigravity.google/docs/mcp?tab=cli), including the CLI tab, specify `~/.gemini/config/mcp_config.json`, `.agents/mcp_config.json`, and `serverUrl`. The manual OAuth example includes both `oauth.clientId` and `oauth.clientSecret`, with `https://antigravity.google/oauth-callback`. The [CLI changelog](https://github.com/google-antigravity/antigravity-cli/blob/800852ea61796e9fe53077a2f945e74daacb4be6/CHANGELOG.md) documents Authenticate in `/mcp`. The public repository contains documentation, not the OAuth implementation. Its [metadata document](https://antigravity.google/oauth/client-metadata.json) declares public-client authentication for CIMD; this does not establish the separate manually configured client-ID path.

A network-denied experiment with the official standalone macOS ARM64 1.3.3 archive found only MCP add/remove/list/enable/disable commands. `agy mcp add --help` exposes no OAuth fields or authentication operation; the archive contains no separate schema. Thus that safe experiment cannot establish omission of `clientSecret` for static registration. The guide records manual public-client setup as a separate state and withholds generated configuration rather than copying a confidential-client example or changing Mmentum's registration model. Real Antigravity authorization remains an evidence gap, not a UI testing disclaimer.

## Recommendation

Use PlanetScale's documentation clarity and Sentry's focused client-specific instruction panel. Borrow Context7's exact configuration examples and troubleshooting, and Cloudflare's plain-language permission presets. Keep Mmentum's existing visual style and OAuth implementation.

The initial journey should be: **Choose client → add configuration → approve access → try a read-only query**. Keep connection management separate from setup. A copied configuration or approved grant must not produce a false “Connected” badge.

## Product boundary

Mmentum already hosts a remote MCP server. The user connects an AI app to that server; they do not provision or deploy a server. Prefer **Connect an AI app** over **Create server**.

The research should answer four questions:

- How does a user choose their client and get the right setup instructions?
- How does the service explain and authorize access?
- How does the user know setup worked?
- How do they review and remove access later?

## Reference: PlanetScale

Sources: [MCP setup](https://planetscale.com/docs/mcp-server), [installed OAuth applications](https://planetscale.com/changelog/installed-oauth-applications), [service tokens](https://planetscale.com/docs/mcp/service-token), [launch article](https://planetscale.com/blog/introducing-planetscale-mcp-server).

**Observed public page structure:** a documentation article with navigation/sidebar and a table of contents. A current desktop browser capture confirms a white/light-gray canvas, strong dark headings, blue article links, a bounded central reading column, and a right-hand contents list. It opens with an overview/video and a quick-start grid of client cards, followed by authentication, security, individual client instructions, example workflows, tools, and troubleshooting. The quick-start source defines three columns and compact client icons, neutral bordered rounded cards, semibold names, and muted descriptions, with light/dark support. The grid's styling comes from source inspection; the captured viewport shows the overview.

**Setup:** Cursor and VS Code cards offer one-click configuration installation. Claude Code, OpenCode, Codex, Notion, and other clients link to instructions. Manual configuration remains available. The user installs the server in their client, opens browser authentication, signs in, grants access, and returns to the client. The instructions name concrete client-side success states and document client-specific workarounds. One-click installation does not bypass approval.

**Permissions:** the docs describe no access/read-only/full access at organization and database level, plus separate payment-method permissions. Organization policy and member roles constrain what a user can grant. This is useful evidence for clear permission language, not a reason to add enterprise resource pickers to Mmentum.

**Management:** the September 28, 2026 announcement documents Organization Settings → OAuth applications → Installed. It lists applications, authorization counts and dates, and provides permission detail and organization-specific revocation. Dynamically registered MCP applications are hidden by default behind “Hide DCR apps.” Mmentum should keep its small list of AI app grants visible.

**Evidence limit:** authenticated consent and management screens were not exercised. The public OAuth documentation's inspected February 2024 screenshot shows developer scope configuration, not current MCP user consent; it must not be treated as a visual reference for that screen.

**Follow-up: agent-first setup.** PlanetScale's [agent setup prompt](https://planetscale.com/docs/agent-setup/prompt) provides a single copy action that tells an agent to fetch its [machine-readable setup instructions](https://planetscale.com/docs/agent-setup/prompt.md). The agent performs setup; the user completes browser approval. Its [agent-guide CLI](https://planetscale.com/docs/cli/agent-guide) and [Claude plugin](https://github.com/planetscale/claude-plugin) provide deeper workflow packaging. For Mmentum's one read-only tool, a self-contained prompt with the actual registered client config is sufficient; no new CLI, plugin, or public setup endpoint is needed.

**Follow-up: real consent footage.** The [official January 2023 OAuth launch article](https://planetscale.com/blog/introducing-planetscale-api-and-oauth-applications) includes a [PlanetPets authorization GIF](https://planetscale.com/assets-2024/blog/content/introducing-planetscale-api-and-oauth-applications/planetpets.gif). Its user-facing screen leads with an app avatar/name and one short permission request, then compact account/resource panels, followed by a centered Authorize access/Cancel row. This is historical evidence, not a claim about today's Cursor consent screen. Mmentum follows that hierarchy while retaining its own styling and showing only permissions it actually enforces.

**Borrow:** client-first entry, direct install where verified, copyable manual instructions, explicit browser handoff, concrete success examples, and visible revocation. Do not copy its database/organization complexity or assume Mmentum supports its URL-only registration flow.

## Reference: Sentry

Sources: [public MCP page](https://mcp.sentry.dev/), [inspected source revision](https://github.com/getsentry/toolkit/tree/5aa112dc47954deb273431a2bc5a5c7d1785314d), [OAuth discovery](https://mcp.sentry.dev/.well-known/oauth-authorization-server), [authorization and revocation docs](https://docs.sentry.io/product/partnership-platform/oauth-integration/), [verification playbook](https://github.com/getsentry/toolkit/blob/main/docs/testing/remote.md).

**Observed public layout:** current desktop captures show a dark plum canvas, purple panels, lavender controls, white headings, and a sticky header. The introduction places a copyable endpoint beside an “Install in Cursor” action. A large terminal/browser demonstration precedes a two-column area: use cases on the left and installation on the right. Installation contains Cloud/Stdio controls, a horizontally scrolling icon-labelled client picker, numbered instructions, and copyable code blocks. Only the selected client's instructions occupy that panel. A Live Demo action opens a separate right-hand account-connection panel.

**Setup:** Cloud is the default transport choice and Claude Code is the default client. The live picker includes Claude Code, Codex, Cursor, Amp, fx, Gemini CLI, OpenCode, Pi, VSCode, Warp, and Zed. Cursor and VSCode provide install deep links plus manual paths; other clients receive commands or configuration. Authentication can require a separate client-side action after installation. The demo has its own authorization; installing the server elsewhere does not connect the demo.

**Consent, from public source:** the screen names the requesting client and offers capability groups for inspecting issues, AI debugging, triage, and project/team management, with descriptions and tool counts. Active groups start selected; repeat requests can remember selections but still require approval. The screen warns about the callback destination and provides Cancel/Approve. Its human-facing capability groups differ from the upstream API scopes. Mmentum should not add capability controls unless the server actually enforces them, and should prefer read-only setup over all-selected permissions.

**Verification and management:** the testing guide recommends identity and organization queries. Account → Authorized Applications provides revocation according to Sentry's docs; that account screen was not visited. Signing out of the public demo only clears its cookie, not the underlying authorization.

**Borrow:** the compact client-specific instruction panel, adjacent copy/install actions, explicit authorization step, and harmless first query. Skip the large animated marketing demonstration and separate demo application for this first slice.

## Reference: Context7

Sources: [client instructions](https://context7.com/docs/resources/all-clients), [API keys](https://context7.com/docs/howto/api-keys), [OAuth](https://context7.com/docs/howto/oauth), [official repository](https://github.com/upstash/context7), [published API-key screenshot](https://context7.com/docs/docs-assets/_docs7/i/1920/images/dashboard/api-keys-card.png.webp).

**Observed documentation structure:** client instructions use per-client accordions with remote/local sections, specific configuration paths, and copyable examples. Account authentication documentation separates API Keys and OAuth from installation and troubleshooting. The published API-key image shows a white rounded panel, explanatory subtitle, top-right Create API Key action, and rows with name, masked key, creation date, last use, and deletion. Its bright green outer framing is not proof of the actual dashboard background.

**Setup:** the automated `npx ctx7 setup` path selects MCP or CLI/Skills, chooses an agent target, and authenticates with a device code. Manual API-key setup creates a named key, reveals it once, and supplies client-specific configuration. OAuth instructions use `https://mcp.context7.com/mcp/oauth` and explicitly warn that adding the server may not start authentication; the user may need to authenticate from client settings.

**Important inconsistency:** examples do not all describe the same installation. The Cursor deep link contains a remote URL without a secret, while reviewed VS Code links install a local `npx` server. The general OAuth guide and Pi example also use different endpoint paths. Treat each client example as a separate contract, not text that can be copied indiscriminately.

**Verification:** tool discovery has named expected tools. A private-library query can establish credentialed access where a ready indicator or ping cannot. Key docs cover one-time reveal and immediate irreversible revocation; public OAuth docs do not establish the exact consent UI or granular grant wording.

**Borrow:** exact configuration location, correct client-specific keys, explicit authentication steps, inline copying, and troubleshooting that separates reachability from authorization. Do not introduce API keys merely because the reference has them; Mmentum already uses OAuth. Last-use information requires backend tracking that Mmentum does not currently have.

## Reference: Cloudflare

Sources: [server catalog](https://developers.cloudflare.com/agents/model-context-protocol/cloudflare/servers-for-cloudflare/), [client connection/testing guide](https://developers.cloudflare.com/agents/model-context-protocol/guides/test-remote-mcp-server/), [launch article](https://blog.cloudflare.com/remote-model-context-protocol-servers-mcp/), [consent renderer](https://github.com/cloudflare/mcp/blob/main/src/auth/workers-oauth-utils.ts), [permission presets](https://github.com/cloudflare/mcp/blob/main/src/auth/scopes.ts), [authorization selection](https://github.com/cloudflare/mcp/blob/main/src/auth/oauth-handler.ts), [published Playground screenshot](https://blog.cloudflare.com/_emdash/api/media/file/01KW46P1T1G72CJRN0Y8PAN76C.png).

**Setup:** the catalog leads with the broad API server at `https://mcp.cloudflare.com/mcp`, then lists product-specific servers by name, purpose, and URL. Users add a URL to their client and complete browser authorization. API-token instructions form a separate automation/headless path. Playground and Inspector guides cover connecting, authorizing, listing tools, and trying a query. A “Deploy to Cloudflare” button in builder material is not an install action for users of an existing server.

**Consent, from public source:** the screen names the app and return destination, offers Read only/Full access presets, and provides advanced scope editing and Cancel/Continue actions. Read-only is the fallback when the client has not explicitly requested additional scopes; it is not an unconditional selection. Explicit client requests can select another preset or a Requested scopes state. MCP consent precedes upstream account authorization.

**Observed published visual:** the launch Playground image uses a light two-column layout, settings on the left and conversation/results on the right. The MCP section exposes endpoint, Connected status, Disconnect, available tools, and debug output. This is a historical client UI with an `/sse` example, not today's provider-side connection-management screen. Current server guidance uses `/mcp` and Streamable HTTP.

**Borrow:** plain-language authority before approval, named tools or expected results during verification, and recovery instructions near setup. Do not copy the debugging playground into account settings, its historical transport example, or a Connected badge without actual connection evidence.

## Evidence boundaries

- Public documentation, repository source, published images, and current desktop captures establish different things. The sections above identify which evidence supports each claim.
- No provider account was signed into, no OAuth request was approved, and no credential was created or revoked.
- Current rendered desktop pages were inspected for PlanetScale and Sentry. Context7 and Cloudflare visual findings rely on published images and public source, not live authenticated dashboards.
- These sources support a design proposal, not end-to-end client compatibility for Mmentum or proof of mobile behavior.

## Existing Mmentum behavior

Checked against the code and `MCP_SERVER_SPEC.md`, not just planned features:

- `/mcp` is an authenticated remote Streamable HTTP endpoint.
- OAuth reuses the existing browser login, shows consent, and returns the user to the client.
- Public clients must already appear in deployment configuration. Dynamic registration and Client ID Metadata Documents are not implemented; an endpoint URL alone is not enough.
- OAuth requires HTTPS, including local development.
- `list_habits` is the only implemented tool. It reads the user's habits and current progress. An empty habit list is a valid result.
- The server supports read and write scopes, but there are no implemented write tools. The initial setup should request read access only.
- Connected apps already lists active grants and supports Disconnect.
- A grant can exist before token exchange finishes. The existing page exposes this as “Awaiting token exchange.”
- There is no stored last-request time or successful-client-verification state. A grant must not be presented as proof that the client is online or that a tool call worked.
- The specification records successful local OAuth checks for OpenCode and Pi. Claude Code has separate message-compatibility evidence, but its earlier isolated token-storage issue remains unresolved. Current versions of the other clients remain unverified.

Behavior owners:

- `lib/mmentum_web/router.ex`: MCP, OAuth, and authenticated account routes
- `lib/mmentum_web/controllers/oauth_controller.ex`: consent rendering and connection management
- `lib/mmentum_web/controllers/oauth_html/consent.html.heex`: approval UI
- `lib/mmentum_web/controllers/oauth_html/connections.html.heex`: existing management UI
- `lib/mmentum/oauth.ex`: configured clients, grants, token exchange, and revocation
- `lib/mmentum/oauth/connection.ex`: persisted connection fields

## Proposed Mmentum surfaces

### 1. Connect an AI app

An authenticated setup page reachable from Connected apps. Proposed route: `/users/connections/new`, outside the existing `/mcp` transport scope.

- Short heading and explanation: “Let your AI app read your habits and current progress.”
- Client selector above a single focused instruction panel. Show instructions for one client at a time rather than every configuration format on one page.
- Show the endpoint with a copy action, then the selected client's command or configuration and a separate copy action.
- Show a one-click install action only when its actual configuration and OAuth flow have been verified against Mmentum.
- Explain the next step before the user leaves: sign in to Mmentum, review access, and return to the client.
- Finish with a read-only verification prompt: “Show my Mmentum habits and current progress.” Explain that a successful empty result also proves the tool worked.
- Put troubleshooting below the primary path. Include unregistered client/callback, HTTPS, authorization denied, and authorized-but-not-working cases.
- Do not add API-key creation, server naming, hosting choices, or a multi-page provisioning wizard.

### 2. Approve access

Refine the existing OAuth consent page without replacing its signed-request, one-use consent, or redirect behavior.

- Client name, current Mmentum account, and the requested access in plain language
- A clear primary approval action and a secondary cancel action
- A concise statement that access can be removed from Connected apps
- No secrets, editable client identity, or permissions that the request did not ask for
- Use read-only access for the initial setup. Do not advertise habit creation or completion recording as available tools

### 3. Connected apps

Improve the existing management page rather than build a separate server inventory.

- Empty state explaining what connecting enables, with **Connect an AI app** as the primary action
- Human-readable configured client name, granted permissions, and approval date for each grant
- Separate pending token exchange from completed authorization; do not claim live connectivity
- Disconnect with a clear explanation that it removes that grant's access, not habits or the client-side configuration
- Show a clear result after disconnecting
- No “last used,” health badge, or verified status until the backend can supply that evidence

## Visual direction for Mmentum

Keep the current product's Poppins typography, neutral surfaces, black primary actions, orange links/focus treatment, shared controls, and light/dark themes. Borrow the references' information hierarchy and setup interactions rather than copy their branding.

Use one bounded content column, a short page header, a compact client selector, and a quiet bordered instruction panel. On small screens, stack controls and keep code overflow inside its panel. Copy actions should give immediate inline feedback. Setup and management belong on full pages; consent should remain a focused approval surface.

## Decisions before implementation

- Confirm the intended first clients. The current evidence favors starting with OpenCode and Pi; other clients need compatibility work before becoming supported choices.
- Confirm whether this means connecting Mmentum to AI apps, rather than building a product for hosting arbitrary user-created MCP servers.
- Expanding OAuth registration or changing permission behavior requires a separate security decision; it is not just a UI change.
