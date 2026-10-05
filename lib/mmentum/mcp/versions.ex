defmodule Mmentum.MCP.Versions do
  @moduledoc "Selects one protocol implementation before validating a request"

  alias Mmentum.MCP.Versions.{V2025_11_25, V2026_07_28}

  @versions %{
    "2025-11-25" => {V2025_11_25.Server, V2025_11_25.Response},
    "2026-07-28" => {V2026_07_28.Server, V2026_07_28.Response}
  }
  @modern Map.fetch!(@versions, "2026-07-28")

  def supported, do: @versions |> Map.keys() |> Enum.sort(:desc)

  def select(%{"method" => "initialize"}, _headers), do: Map.fetch!(@versions, "2025-11-25")

  def select(%{"params" => %{"_meta" => %{"io.modelcontextprotocol/protocolVersion" => _}}}, _headers),
    do: @modern

  def select(_request, headers) do
    case for({"mcp-protocol-version", version} <- headers, do: version) do
      [version] -> Map.get(@versions, version, @modern)
      _missing_or_repeated -> @modern
    end
  end
end
