defmodule Mmentum.MCP.Server do
  @moduledoc """
  Handles MCP operations such as discovering the server and listing tools

  Receives validated requests from the transport and returns results or named
  failures. It does not parse HTTP, validate requests, or write responses thats
  for `Mmentum.MCP.Transport.StreamableHTTP` to handle before this.
  """

  require Logger

  alias Mmentum.Tools

  @protocol_version "2026-07-28"

  def protocol_version, do: @protocol_version

  @doc "Handler for MCP server requests"
  def handle(%{"method" => method}) do
    Logger.info("MCP: Handling #{method} request")

    case method do
      "server/discover" -> server_discover()
      "tools/list" -> tools_list()
      _ -> {:error, :method_not_found, "Method #{method} not found"}
    end
  end

  def server_discover() do
    complete(%{
      "supportedVersions" => [@protocol_version],
      "capabilities" => %{"tools" => %{}},
      "ttlMs" => to_timeout(hour: 1),
      "cacheScope" => "public"
    })
  end

  def tools_list() do
    complete(%{
      "tools" => Tools.definitions(),
      "ttlMs" => 0,
      "cacheScope" => "private"
    })
  end

  defp complete(result) do
    {:ok,
     Map.merge(result, %{
       "resultType" => "complete",
       "_meta" => %{
         "io.modelcontextprotocol/serverInfo" => %{
           "name" => "mmentum",
           "version" => to_string(Application.spec(:mmentum, :vsn))
         }
       }
     })}
  end
end
