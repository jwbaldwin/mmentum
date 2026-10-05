defmodule Mmentum.MCP.Versions.V2026_07_28.Response do
  @moduledoc "Builds MCP 2026-07-28 results and errors"

  @error_codes %{
    parse_error: -32_700,
    invalid_request: -32_600,
    method_not_found: -32_601,
    invalid_params: -32_602,
    internal_error: -32_603,
    header_mismatch: -32_020,
    unsupported_protocol_version: -32_022
  }

  def result(id, result) do
    result =
      Map.merge(result, %{
        "resultType" => "complete",
        "_meta" => %{
          "io.modelcontextprotocol/serverInfo" => %{
            "name" => "mmentum",
            "version" => to_string(Application.spec(:mmentum, :vsn))
          }
        }
      })

    %{"jsonrpc" => "2.0", "id" => id, "result" => result}
  end

  def tool_call(id, {:ok, tool_result}) do
    {200,
     result(id, %{
       "structuredContent" => tool_result,
       "content" => [%{"type" => "text", "text" => Jason.encode!(tool_result)}],
       "isError" => false
     })}
  end

  def tool_call(id, {:error, :tool_not_found}),
    do: {400, error(id, :invalid_params, "Unknown tool")}

  def tool_call(id, {:error, _reason, message}) do
    {200, result(id, %{"isError" => true, "content" => [%{"type" => "text", "text" => message}]})}
  end

  def error(id, reason, message, data \\ nil) do
    error = %{"code" => Map.fetch!(@error_codes, reason), "message" => message}
    error = if is_nil(data), do: error, else: Map.put(error, "data", data)

    response = %{"jsonrpc" => "2.0", "error" => error}
    if is_nil(id), do: response, else: Map.put(response, "id", id)
  end

  @doc "Returns a valid request id, or nil when an invalid request cannot be identified"
  def request_id(%{"id" => id}) when is_binary(id) or is_integer(id), do: id
  def request_id(_request), do: nil
end
