defmodule Mmentum.MCP.Versions.V2026_07_28.Server do
  @moduledoc "Handles MCP 2026-07-28 requests without connection state"

  require Logger

  alias Mmentum.Tools
  alias Mmentum.MCP.Versions
  alias Mmentum.MCP.Versions.V2026_07_28.{Request, Response}

  @protocol_version "2026-07-28"

  def protocol_version, do: @protocol_version

  def handle(request, headers) do
    case Request.validate(request, headers) do
      :ok -> dispatch(request)
      {:error, status, response} -> {status, response}
    end
  end

  defp dispatch(%{"id" => id, "method" => method}) do
    Logger.info("MCP: Handling #{method} request")

    case method do
      "server/discover" -> {200, Response.result(id, server_discover())}
      "tools/list" -> {200, Response.result(id, tools_list())}
      _ -> {404, Response.error(id, :method_not_found, "Method #{method} not found")}
    end
  end

  defp dispatch(_notification), do: {202, nil}

  defp server_discover() do
    %{
      "supportedVersions" => Versions.supported(),
      "capabilities" => %{"tools" => %{}},
      "ttlMs" => to_timeout(hour: 1),
      "cacheScope" => "public"
    }
  end

  defp tools_list() do
    %{
      "tools" => Tools.definitions(),
      "ttlMs" => 0,
      "cacheScope" => "private"
    }
  end
end
