defmodule MmentumWeb.MCPComponents do
  @moduledoc false
  use MmentumWeb, :html

  @client_marks %{
    "cursor" => {"cursor-light.svg", "cursor-dark.svg"},
    "vscode" => {"vscode.svg", "vscode.svg"},
    "claude-code" => {"claude.svg", "claude.svg"},
    "opencode" => {"opencode-light.svg", "opencode-dark.svg"},
    "codex" => {"codex-light.svg", "codex-dark.svg"},
    "chatgpt" => {"codex-light.svg", "codex-dark.svg"},
    "claude" => {"claude.svg", "claude.svg"},
    "gemini" => {"gemini-cli.svg", "gemini-cli.svg"},
    "amp" => {"amp.svg", "amp.svg"},
    "notion" => {"notion.svg", "notion.svg"},
    "pi" => {"pi.svg", "pi.svg"}
  }

  attr :client_key, :string, default: nil
  attr :class, :string, default: "h-6 w-6"

  def client_logo(assigns) do
    assigns = assign(assigns, :marks, @client_marks[assigns.client_key])

    ~H"""
    <span aria-hidden="true" class={[@class, "inline-flex flex-none items-center justify-center"]}>
      <%= if @marks do %>
        <img src={~p"/images/mcp-clients/#{elem(@marks, 0)}"} alt="" class="h-full w-full object-contain dark:hidden" />
        <img src={~p"/images/mcp-clients/#{elem(@marks, 1)}"} alt="" class="hidden h-full w-full object-contain dark:block" />
      <% else %>
        <.icon name="hero-link" class="h-full w-full text-muted dark:text-zinc-400" />
      <% end %>
    </span>
    """
  end

  attr :id, :string, required: true
  attr :text, :string, required: true
  attr :label, :string, required: true
  attr :multiline, :boolean, default: false

  def copy_block(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook="CopyText"
      data-copy-idle-label="Copy"
      class="min-w-0 overflow-hidden rounded-control border border-zinc-200 bg-zinc-50 dark:border-zinc-800 dark:bg-zinc-900/50"
    >
      <div class="flex items-center justify-between gap-3 border-b border-zinc-200 px-4 py-2 dark:border-zinc-800">
        <span class="min-w-0 truncate text-xs font-medium text-muted dark:text-zinc-400">{@label}</span>
        <.button
          id={"#{@id}-copy"}
          type="button"
          variant="quiet"
          size="compact"
          class="shrink-0"
          data-copy-button
          aria-label={"Copy #{@label}"}
        >
          <.icon name="hero-square-2-stack" class="h-4 w-4" />
          <span data-copy-label>Copy</span>
        </.button>
      </div>
      <pre class={[
        "overflow-x-auto p-4 text-xs leading-6 text-zinc-800 dark:text-zinc-200 sm:text-sm",
        !@multiline && "whitespace-pre-wrap [overflow-wrap:anywhere]"
      ]}><code data-copy-content>{@text}</code></pre>
      <p data-copy-status role="status" class="sr-only"></p>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :text, :string, required: true
  attr :label, :string, default: "Copy setup prompt"

  def copy_action(assigns) do
    ~H"""
    <div id={@id} phx-hook="CopyText" data-copy-idle-label={@label} class="min-w-0 max-w-full">
      <.button id={"#{@id}-copy"} type="button" data-copy-button>
        <.icon name="hero-square-2-stack" class="h-4 w-4" />
        <span data-copy-label>{@label}</span>
      </.button>
      <p data-copy-status role="status" class="sr-only"></p>
      <pre
        data-copy-fallback
        hidden
        class="mt-3 overflow-x-auto rounded-control border border-zinc-200 p-4 text-xs leading-6 dark:border-zinc-800"
      ><code data-copy-content>{@text}</code></pre>
    </div>
    """
  end

  attr :scopes, :list, required: true

  def permissions(assigns) do
    ~H"""
    <ul class="space-y-3 text-sm leading-6">
      <li :if={"mmentum:read" in @scopes} class="flex items-start gap-3">
        <.icon name="hero-eye" class="mt-0.5 h-5 w-5 flex-none text-muted dark:text-zinc-400" />
        <div>
          <p class="font-medium text-zinc-900 dark:text-zinc-100">Read your habits</p>
          <p class="text-muted dark:text-zinc-400">Habits and current progress</p>
        </div>
      </li>
      <li :if={"mmentum:write" in @scopes} class="flex items-start gap-3">
        <.icon name="hero-pencil-square" class="mt-0.5 h-5 w-5 flex-none text-muted dark:text-zinc-400" />
        <div>
          <p class="font-medium text-zinc-900 dark:text-zinc-100">Change habits and record progress</p>
          <p class="text-muted dark:text-zinc-400">
            No write tools yet. This permission applies when they're added.
          </p>
        </div>
      </li>
    </ul>
    """
  end
end
