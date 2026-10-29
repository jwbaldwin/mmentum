# MCP Apps and ChatGPT Plugin Extensions

Status: proposed architecture for review, not implemented or approved for implementation

The MCP server milestone is complete. This proposal adds an interactive habit view on top of the existing tools, then exposes the same view through ChatGPT-specific launch surfaces. The in-app Mmentum agent remains separate work

## Two Layers

MCP Apps provides the shared UI foundation: an HTML resource, a render tool that points to it, and a host bridge for receiving results and calling tools

OpenAI Plugin Extensions adds ChatGPT-specific surfaces, including a sidebar launch and a conversation side panel. These reuse the same component rather than introducing another habit backend or UI implementation

Ordinary MCP clients keep using the existing data tools without needing to render a component

## First Slice

- Show habits and their current progress
- Record a completion through the existing completion tool
- Open a habit's current and previous periods
- Page through complete history
- Use the same component inline, from the ChatGPT sidebar, and beside a conversation

Elixir owns authentication, authorization, calendar rules, progress, and writes. The component displays server results and sends tool calls through its host

## Proposed Modules

The sketches below are pseudocode, not executable Elixir or JavaScript. Lifecycle event names describe responsibilities; implementation must map them to the current MCP Apps SDK and host launch behavior

### 1. Mmentum.Tools.RenderHabits

File: `lib/mmentum/tools/render_habits.ex`

Choose which habits to display. Register the tool in the existing `Mmentum.Tools` catalog and require read permission

Accept optional habit IDs selected from a preceding `list_habits` result. Omitting the field means all habits; an explicit empty list means an empty selection. Return the selection with `habit_ids: null` for all habits

```text
module RenderHabits
  @input_schema:
    habit_ids: optional list of Tool.id_schema()

  @output_schema:
    habit_ids: list of IDs or null

  required_scope: :read
  annotations: read-only, not destructive, not open-world

  execute(context, arguments):
    selection = validate(@input_schema, arguments)
    return {:ok, normalize_selection(selection)}
end
```

This tool does not query habits again, accept names and progress supplied by the model as truth, or make changes. The component fetches current records through the existing data tools

The tradeoff is one read when opening the view. IDs are presentation choices, not proof of access. Every data read and write still checks the authenticated user. Missing or inaccessible selections must not reveal another user's habit or silently show a different selection

### 2. Mmentum.MCP.HabitApp

File: `lib/mmentum/mcp/habit_app.ex`

Own the MCP presentation contract: resource URI, resource contents, security policy, and tool metadata. Keep this knowledge out of the shared tool definitions and application operations

```text
module HabitApp
  resource_uri = "ui://mmentum/habits/v1.html"

  list_resources():
    return [
      {uri: resource_uri,
       name: "Mmentum habits",
       mime_type: "text/html;profile=mcp-app"}
    ]

  read_resource(uri):
    match uri against the registered resource
    return HTML rendered by MmentumWeb.MCPHTML
    unknown URI -> resource-not-found error

  decorate_tool(definition):
    when definition.name == "render_habits":
      attach:
        _meta.ui.resourceUri = resource_uri
        _meta["openai/ui"].entrypoints = [
          {type: "global"},
          {type: "thread"}
        ]

    return definition
end
```

Only the render tool points to a UI resource. Data tools remain reusable without repeatedly mounting the component

The same resource serves inline conversations, sidebar launches, and conversation panels. Standard MCP Apps metadata links the resource; OpenAI-specific metadata adds the launch surfaces

Resource contents contain application code, not a user's habits, bearer tokens, or browser session. Declare the MCP Apps MIME type and the supported display modes. Keep the CSP allowlists limited to actual dependencies. With bundled assets and host-mediated tool calls, no direct API connections should be needed

Read only the registered resource, never an arbitrary path derived from a URI. Change the resource URI when making an incompatible bundle change so host caches cannot pair old code with a new contract

### 3. MmentumWeb.MCPHTML

Files:

- `lib/mmentum_web/controllers/mcp_html.ex`
- `lib/mmentum_web/controllers/mcp_html/habit_app.html.heex`

Build a self-contained HTML document from the component bundle and styles

```text
module MCPHTML
  habit_app():
    render document containing:
      application root
      bundled CSS
      bundled JavaScript
end
```

This is not an embedded LiveView page. It has no separate login, websocket, or browser-owned habit API

Extend the existing asset tasks to build its JavaScript and CSS and include them in the release. Keep authored JavaScript in the assets directory, not in the HEEx template. Reuse design tokens where practical without embedding the entire web application

Resolve resource assembly before implementation: the current Boundary rules forbid calls from `Mmentum` into `MmentumWeb`. The sketch above describes the HTML handoff, not permission to add a direct domain-to-web dependency. Use a built HTML artifact or a web-owned assembly boundary without weakening that rule

### 4. Browser Component

File: `assets/js/mcp/habits_app.js`

Own the visible habit list, history view, and temporary interaction state. Use plain JavaScript plus the standard MCP Apps client SDK, not React or a hand-built messaging protocol

```text
state = {
  selection: allHabits,
  screen: habitList,
  selectedHabitId: null,
  pendingAction: null,
  error: null
}

connectToHost()

onRenderToolResult(selection):
  validateSelection(selection)
  loadHabits(selection)

onDirectLaunchWithoutRenderResult():
  loadHabits(allHabits)

loadHabits(selection):
  result = host.callTool("list_habits", {})
  validateListResult(result)
  displayRequestedHabits(result, selection)

openHabit(habitId):
  result = host.callTool("get_habit", { habit_id: habitId })
  validateHabitResult(result)
  displayHabitAndRecentHistory(result)

loadMoreHistory(cursor):
  result = host.callTool("get_habit", {
    habit_id: state.selectedHabitId,
    history: "all",
    cursor
  })
  validateHabitResult(result)
  displayNextHistoryPage(result)

completeHabit(habitId):
  disableActionWhilePending()

  try:
    result = host.callTool("manage_habit_completions", {
      add: [{ habit_id: habitId }]
    })

    if successful:
      reloadVisibleHabitData()
    else:
      displayError()
  on transport failure:
    displayUncertainOutcomeAndOfferReload()
  finally:
    enableAction()
```

The completion input key is `add`, matching the existing tool. The response contains `added` and `removed`

Handle RPC errors and tool results with `isError` before reading `structuredContent`. Validate results at the browser boundary and display names as text, not HTML

Tool results drive counts and history. The component does not calculate domain progress or calendar boundaries. Use the returned time zone and UTC timestamps for presentation

Selection, navigation, loading, and errors stay in component memory. Keep stale asynchronous responses from replacing the currently selected habit or a newer result

Let the host handle authentication and approvals. Missing initial input while a tool waits for approval is not a direct launch and must not trigger an unrelated load. Initialize the host bridge before making tool calls, use its theme and size signals, and remove listeners on destruction

Never automatically retry completion writes: additions are not deduplicated. Disable repeated clicks while a request is pending. If the outcome is unclear after a transport failure, reload server state rather than assuming the write failed. If the write succeeds but the refresh fails, report the refresh failure without offering to repeat the write

## Changes to Existing Modules

Both protocol namespaces keep their current responsibilities

```text
Request.parse:
  validate resources/list parameters
  validate resources/read requires a string URI
  preserve existing version and header checks

Server.dispatch:
  resources/list -> HabitApp.list_resources()
  resources/read -> HabitApp.read_resource(uri)

  tools/list:
    Tools.definitions()
    |> decorate with HabitApp metadata

Response:
  advertise resources capability
  format resource results and resource-not-found errors
  preserve each protocol version's response envelope
```

Relevant files live under:

- `lib/mmentum/mcp/versions/v2025_11_25/`
- `lib/mmentum/mcp/versions/v2026_07_28/`

Keep protocol validation and response formatting version-specific. Both versions use the same resource owner, browser bundle, and tool registry. Do not add another generic server or resource framework for one component

Register `RenderHabits` in `lib/mmentum/tools.ex`. Keep OpenAI metadata in the MCP presentation boundary, not in the shared tools or domain contexts

Do not change OAuth, habit persistence, completion locking, or the existing five tool response shapes. No new database tables or background processes are needed

## Delivery and Review

1. Build the shared MCP Apps path first: resource reading, render tool, host initialization, list, completion, and history
2. Verify the component through a real host, including denied writes, approval delays, and failed refreshes
3. Add ChatGPT sidebar and conversation entrypoints to the same component, then verify direct launches and the supported layouts

Before declaring this milestone complete, prove resource and tool behavior through authenticated requests in both protocol versions. Check that ordinary clients can still use the data tools without UI, and exercise the browser interactions in a real MCP Apps host. Backend tests alone do not prove sandbox behavior, layout, host approvals, or ChatGPT account availability

Host compatibility remains a separate claim from server protocol support. Record which client, version, surface, and OAuth flow were actually exercised

## Out of Scope

Settings, file viewers, rich forms, deep links, composer mentions, durable widget preferences, and the in-app agent remain separate work. Add them only for a concrete product need after the first slice works. They attach to the existing resource and component rather than requiring a general extension framework now

## References

- [Add UI to your MCP server](https://developers.openai.com/plugins/build/chatgpt-ui)
- [Plugin Extensions](https://developers.openai.com/plugins/build/extensions)
- [UI API reference](https://developers.openai.com/plugins/reference)
- [MCP Apps standard](https://modelcontextprotocol.io/docs/extensions/apps)
- [Current MCP server specification](../MCP_SERVER_SPEC.md)
