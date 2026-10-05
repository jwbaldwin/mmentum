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

  def tool_call(id, {:ok, tool_result}) do
    {200,
     result(id, %{
       "structuredContent" => tool_result,
       "content" => [%{"type" => "text", "text" => Jason.encode!(tool_result)}],
       "isError" => false
     })}
  end

  def tool_call(id, {:error, :tool_not_found}), do: {200, error(id, :invalid_params, "Unknown tool")}

  def tool_call(id, {:error, _reason, message}) do
    {200, result(id, %{"isError" => true, "content" => [%{"type" => "text", "text" => message}]})}
  end

  def error(id, reason, message) do
    response = %{"jsonrpc" => "2.0", "error" => %{"code" => Map.fetch!(@error_codes, reason), "message" => message}}
    if is_nil(id), do: response, else: Map.put(response, "id", id)
  end

  def request_id(%{"id" => id}) when is_binary(id) or is_integer(id), do: id
  def request_id(_request), do: nil
end
