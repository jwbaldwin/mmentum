defmodule Mmentum.MCP.Usage do
  @moduledoc """
  Logs bounded completion facts for authenticated MCP dispatches across protocol versions

  The transport supplies verified token claims. Protocol servers and Tools retain
  request validation and execution; no arguments, results, or identities are logged
  """

  alias Mmentum.OAuth
  alias Mmentum.Tools
  alias Mmentum.Tools.Context

  require Logger

  @methods ~w(initialize ping server/discover tools/list tools/call)
  @clients ~w(cursor vscode claude-code opencode codex chatgpt claude antigravity gemini amp notion pi other)

  @doc "Invokes the selected protocol server, logs its outcome, and preserves failures unchanged"
  @spec invoke(module(), term(), [{String.t(), String.t()}], Context.t(), map()) :: {integer(), map() | nil}
  def invoke(server, request, headers, context, claims) do
    metadata = [
      mcp_method: method(request),
      mcp_tool: tool(request),
      mcp_client: client(claims),
      mcp_protocol: server.protocol_version()
    ]

    started_at = System.monotonic_time(:microsecond)

    try do
      response = server.handle(request, headers, context)
      log_completion(metadata, started_at, outcome(response))
      response
    catch
      kind, reason ->
        log_completion(metadata, started_at, :exception)
        :erlang.raise(kind, reason, __STACKTRACE__)
    end
  end

  defp method(%{"method" => method}) when method in @methods, do: method
  defp method(%{"method" => "notifications/" <> _rest}), do: "notification"
  defp method(_request), do: "unknown"

  defp tool(%{"method" => "tools/call", "params" => %{"name" => name}}) do
    Enum.find(Tools.names(), "unknown", &(&1 == name))
  end

  defp tool(%{"method" => "tools/call"}), do: "unknown"
  defp tool(_request), do: "none"

  defp client(%{"client_id" => id}) do
    with {:ok, registration} <- OAuth.load_client(id),
         key when key in @clients <- registration["setup_client"] do
      key
    else
      _unmapped -> "unknown"
    end
  end

  defp client(_claims), do: "unknown"

  defp outcome({_status, %{"error" => _error}}), do: :protocol_error
  defp outcome({_status, %{"result" => %{"isError" => true}}}), do: :tool_error
  defp outcome({202, nil}), do: :notification
  defp outcome({_status, %{"result" => _result}}), do: :success

  defp log_completion(metadata, started_at, outcome) do
    duration_us = System.monotonic_time(:microsecond) - started_at
    Logger.info("mcp_request_completed", metadata ++ [mcp_outcome: outcome, mcp_duration_us: duration_us])
  end
end
