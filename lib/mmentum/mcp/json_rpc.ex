defmodule Mmentum.MCP.JSONRPC do
  @moduledoc """
  Responsible for building JSON-RPC replies and owning all the named MCP error codes
  """

  @error_codes %{
    parse_error: -32_700,
    invalid_request: -32_600,
    method_not_found: -32_601,
    invalid_params: -32_602,
    internal_error: -32_603,
    header_mismatch: -32_020,
    unsupported_protocol_version: -32_022
  }

  def result(id, result), do: %{"jsonrpc" => "2.0", "id" => id, "result" => result}

  def error(id, reason, message, data \\ nil) do
    error = %{"code" => Map.fetch!(@error_codes, reason), "message" => message}
    error = if is_nil(data), do: error, else: Map.put(error, "data", data)

    %{"jsonrpc" => "2.0", "id" => id, "error" => error}
  end

  @doc "Returns a valid request id, or nil when an invalid request cannot be identified"
  def response_id(%{"id" => id}) when is_binary(id) or is_integer(id), do: id
  def response_id(_request), do: nil
end
