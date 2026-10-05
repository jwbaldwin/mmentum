defmodule Mmentum.MCP.Versions.V2025_11_25.Server do
  @moduledoc """
  Dispatches MCP 2025-11-25 operations without issuing or storing sessions

  Request parses messages and checks headers; Response formats protocol replies
  The HTTP transport sends the returned status and body
  """

  alias Mmentum.MCP.Versions.V2025_11_25.Request
  alias Mmentum.MCP.Versions.V2025_11_25.Response
  alias Mmentum.Tools

  require Logger

  def protocol_version, do: "2025-11-25"

  def handle(request, headers, context) do
    case Request.parse(request, headers) do
      {:ok, request} -> dispatch(request, context)
      {:error, status, response} -> {status, response}
    end
  end

  defp dispatch(%{"id" => id, "method" => method} = request, context) do
    Logger.info("MCP: Handling #{method} request")

    case method do
      "initialize" -> {200, Response.initialize(id, protocol_version())}
      "ping" -> {200, Response.result(id, %{})}
      "tools/list" -> tools_list(id)
      "tools/call" -> tools_call(id, Map.fetch!(request, "params"), context)
      _ -> {200, Response.error(id, :method_not_found, "Method #{method} not found")}
    end
  end

  defp dispatch(_notification, _context), do: {202, nil}

  defp tools_list(id) do
    catalog = %{"tools" => Tools.definitions()}
    {200, Response.result(id, catalog)}
  end

  defp tools_call(id, %{"name" => name, "arguments" => arguments}, context) do
    outcome = Tools.execute(name, context, arguments)
    Response.tool_call(id, outcome)
  end
end
