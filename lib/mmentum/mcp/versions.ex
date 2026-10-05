defmodule Mmentum.MCP.Versions do
  @moduledoc "Selects one protocol implementation before validating a request"

  alias Mmentum.MCP.Versions.V2025_11_25
  alias Mmentum.MCP.Versions.V2026_07_28

  defp versions do
    %{
      "2025-11-25" => {V2025_11_25.Server, V2025_11_25.Response},
      "2026-07-28" => {V2026_07_28.Server, V2026_07_28.Response}
    }
  end

  def supported, do: versions() |> Map.keys() |> Enum.sort(:desc)

  def select(%{"method" => "initialize"}, _headers), do: Map.fetch!(versions(), "2025-11-25")

  def select(%{"params" => %{"_meta" => %{"io.modelcontextprotocol/protocolVersion" => _}}}, _headers),
    do: Map.fetch!(versions(), "2026-07-28")

  def select(_request, headers) do
    versions = versions()
    modern = Map.fetch!(versions, "2026-07-28")

    case for({"mcp-protocol-version", version} <- headers, do: version) do
      [version] -> Map.get(versions, version, modern)
      _missing_or_repeated -> modern
    end
  end
end
