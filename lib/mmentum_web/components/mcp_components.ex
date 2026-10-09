defmodule MmentumWeb.MCPComponents do
  @moduledoc false
  use MmentumWeb, :html

  attr :id, :string, required: true
  attr :text, :string, required: true
  attr :label, :string, required: true
  attr :multiline, :boolean, default: false

  def copy_block(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook="CopyText"
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

  attr :scopes, :list, required: true

  def permissions(assigns) do
    ~H"""
    <ul class="space-y-3 text-sm leading-6">
      <li :if={"mmentum:read" in @scopes} class="flex items-start gap-3">
        <.icon name="hero-eye" class="mt-0.5 h-5 w-5 flex-none text-muted dark:text-zinc-400" />
        <div>
          <p class="font-medium text-zinc-900 dark:text-zinc-100">Read your habits</p>
          <p class="text-muted dark:text-zinc-400">View your habits and current progress</p>
        </div>
      </li>
      <li :if={"mmentum:write" in @scopes} class="flex items-start gap-3">
        <.icon name="hero-pencil-square" class="mt-0.5 h-5 w-5 flex-none text-muted dark:text-zinc-400" />
        <div>
          <p class="font-medium text-zinc-900 dark:text-zinc-100">Change habits and record progress</p>
          <p class="text-muted dark:text-zinc-400">
            Write tools are not available yet. This permission also applies when they are added.
          </p>
        </div>
      </li>
    </ul>
    """
  end
end
