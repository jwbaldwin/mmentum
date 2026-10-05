defmodule Mmentum.MCP.Versions.V2025_11_25.Response do
  @moduledoc "Builds initialization-era MCP results and errors"

  @error_codes %{
    parse_error: -32_700,
    invalid_request: -32_600,
    method_not_found: -32_601,
    invalid_params: -32_602
  }

  def result(id, result), do: %{"jsonrpc" => "2.0", "id" => id, "result" => result}

  def initialize(id, version) do
    result(id, %{
      "protocolVersion" => version,
      "capabilities" => %{"tools" => %{}},
      "serverInfo" => %{"name" => "mmentum", "version" => to_string(Application.spec(:mmentum, :vsn))}
    })
  end

  def error(id, reason, message) do
    response = %{"jsonrpc" => "2.0", "error" => %{"code" => Map.fetch!(@error_codes, reason), "message" => message}}
    if is_nil(id), do: response, else: Map.put(response, "id", id)
  end

  def request_id(%{"id" => id}) when is_binary(id) or is_integer(id), do: id
  def request_id(_request), do: nil
end
