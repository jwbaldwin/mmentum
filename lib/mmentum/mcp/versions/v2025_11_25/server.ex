defmodule Mmentum.MCP.Versions.V2025_11_25.Server do
  @moduledoc "Handles initialization-era MCP without issuing or storing sessions"

  require Logger

  alias Mmentum.Tools
  alias Mmentum.MCP.Versions.V2025_11_25.{Request, Response}

  def protocol_version, do: "2025-11-25"

  def handle(request, headers) do
    case Request.validate(request, headers) do
      :ok -> dispatch(request)
      {:error, status, response} -> {status, response}
    end
  end

  defp dispatch(%{"id" => id, "method" => method}) do
    Logger.info("MCP: Handling #{method} request")

    case method do
      "initialize" -> {200, Response.initialize(id, protocol_version())}
      "ping" -> {200, Response.result(id, %{})}
      "tools/list" -> {200, Response.result(id, %{"tools" => Tools.definitions()})}
      _ -> {200, Response.error(id, :method_not_found, "Method #{method} not found")}
    end
  end

  defp dispatch(_notification), do: {202, nil}
end
