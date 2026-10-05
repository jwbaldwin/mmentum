defmodule Mmentum.MCP.Versions.V2026_07_28.Server do
  @moduledoc """
  Dispatches MCP 2026-07-28 operations to the shared tool registry

  Request parses messages and checks headers; Response formats protocol replies
  The HTTP transport sends the returned status and body
  """

  alias Mmentum.MCP.Versions
  alias Mmentum.MCP.Versions.V2026_07_28.Request
  alias Mmentum.MCP.Versions.V2026_07_28.Response
  alias Mmentum.Tools

  require Logger

  @protocol_version "2026-07-28"

  def protocol_version, do: @protocol_version

  def handle(request, headers, context) do
    case Request.parse(request, headers) do
      {:ok, request} -> dispatch(request, context)
      {:error, status, response} -> {status, response}
    end
  end

  defp dispatch(%{"id" => id, "method" => method} = request, context) do
    Logger.info("MCP: Handling #{method} request")

    case method do
      "server/discover" -> server_discover(id)
      "tools/list" -> tools_list(id)
      "tools/call" -> tools_call(id, Map.fetch!(request, "params"), context)
      _ -> {404, Response.error(id, :method_not_found, "Method #{method} not found")}
    end
  end

  defp dispatch(_notification, _context), do: {202, nil}

  defp server_discover(id) do
    discovery = %{
      "supportedVersions" => Versions.supported(),
      "capabilities" => %{"tools" => %{}},
      "ttlMs" => to_timeout(hour: 1),
      "cacheScope" => "public"
    }

    {200, Response.result(id, discovery)}
  end

  defp tools_list(id) do
    catalog = %{
      "tools" => Tools.definitions(),
      "ttlMs" => 0,
      "cacheScope" => "private"
    }

    {200, Response.result(id, catalog)}
  end

  defp tools_call(id, %{"name" => name, "arguments" => arguments}, context) do
    outcome = Tools.execute(name, context, arguments)
    Response.tool_call(id, outcome)
  end
end
