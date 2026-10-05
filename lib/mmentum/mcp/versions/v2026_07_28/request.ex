defmodule Mmentum.MCP.Versions.V2026_07_28.Request do
  @moduledoc """
  Parses MCP 2026-07-28 messages and checks their mirrored HTTP headers

  Supplies omitted tool arguments as an empty object before Server dispatches
  Response formats validation failures
  """

  alias Mmentum.MCP.Versions
  alias Mmentum.MCP.Versions.V2026_07_28.Response
  alias Mmentum.MCP.Versions.V2026_07_28.Server

  def parse(request, headers) do
    with :ok <- validate_message(request),
         :ok <- validate_metadata(request),
         :ok <- validate_params(request),
         :ok <- validate_headers(headers, request) do
      request =
        case request do
          %{"method" => "tools/call", "params" => params} ->
            Map.put(request, "params", Map.put_new(params, "arguments", %{}))

          _request ->
            request
        end

      {:ok, request}
    end
  end

  defp validate_message(%{"jsonrpc" => "2.0", "method" => method} = request) when is_binary(method) do
    valid_id? = not Map.has_key?(request, "id") or not is_nil(Response.request_id(request))

    cond do
      not valid_id? -> error(400, request, :invalid_request, "Request ID must be a string or integer")
      not is_map(Map.get(request, "params", %{})) -> error(400, request, :invalid_params, "params must be an object")
      true -> :ok
    end
  end

  defp validate_message(request), do: error(400, request, :invalid_request, "Invalid Request")

  defp validate_metadata(
         %{
           "id" => _id,
           "params" => %{
             "_meta" =>
               %{
                 "io.modelcontextprotocol/protocolVersion" => version,
                 "io.modelcontextprotocol/clientCapabilities" => capabilities
               } = metadata
           }
         } = request
       )
       when is_binary(version) and is_map(capabilities) do
    cond do
      not valid_capabilities?(capabilities) ->
        error(400, request, :invalid_params, "Invalid clientCapabilities")

      not optional_field?(metadata, "io.modelcontextprotocol/clientInfo", &valid_client_info?/1) ->
        error(400, request, :invalid_params, "Invalid clientInfo")

      not optional_field?(
        metadata,
        "io.modelcontextprotocol/logLevel",
        &(&1 in ~w(debug info notice warning error critical alert emergency))
      ) ->
        error(400, request, :invalid_params, "Invalid logLevel")

      not optional_field?(metadata, "progressToken", &(is_binary(&1) or is_integer(&1))) ->
        error(400, request, :invalid_params, "Invalid progressToken")

      true ->
        :ok
    end
  end

  defp validate_metadata(%{"id" => _id} = request),
    do: error(400, request, :invalid_params, "Invalid or missing request metadata")

  defp validate_metadata(_notification), do: :ok

  defp validate_params(%{"method" => "tools/list", "params" => params} = request) do
    if optional_field?(params, "cursor", &is_binary/1),
      do: :ok,
      else: error(400, request, :invalid_params, "cursor must be a string")
  end

  defp validate_params(%{"method" => "tools/call"} = request) do
    case request do
      %{"params" => %{"name" => name} = params} when is_binary(name) ->
        if optional_field?(params, "arguments", &is_map/1),
          do: :ok,
          else: error(400, request, :invalid_params, "arguments must be an object")

      _invalid ->
        error(400, request, :invalid_params, "Tool name must be a string")
    end
  end

  defp validate_params(_request), do: :ok

  defp valid_capabilities?(capabilities) do
    optional_field?(capabilities, "roots", &is_map/1) and
      optional_field?(capabilities, "sampling", &object_fields?(&1, ~w(context tools))) and
      optional_field?(capabilities, "elicitation", &object_fields?(&1, ~w(form url))) and
      optional_field?(capabilities, "experimental", &object_values?/1) and
      optional_field?(capabilities, "extensions", &object_values?/1)
  end

  defp object_values?(settings) when is_map(settings) do
    Enum.all?(settings, fn {_name, options} -> is_map(options) end)
  end

  defp object_values?(_settings), do: false

  defp object_fields?(value, fields) do
    is_map(value) and Enum.all?(fields, &optional_field?(value, &1, fn field -> is_map(field) end))
  end

  defp valid_client_info?(%{"name" => name, "version" => version} = info) when is_binary(name) and is_binary(version) do
    Enum.all?(~w(title description), &optional_field?(info, &1, fn value -> is_binary(value) end)) and
      optional_field?(info, "websiteUrl", &absolute_uri?/1) and
      optional_field?(info, "icons", fn icons -> is_list(icons) and Enum.all?(icons, &valid_icon?/1) end)
  end

  defp valid_client_info?(_info), do: false

  defp valid_icon?(%{"src" => src} = icon) do
    absolute_uri?(src) and optional_field?(icon, "mimeType", &is_binary/1) and
      optional_field?(icon, "theme", &(&1 in ["light", "dark"])) and
      optional_field?(icon, "sizes", fn sizes -> is_list(sizes) and Enum.all?(sizes, &is_binary/1) end)
  end

  defp valid_icon?(_icon), do: false

  defp absolute_uri?(value) when is_binary(value) do
    case URI.new(value) do
      {:ok, %URI{scheme: scheme}} when is_binary(scheme) -> true
      _invalid -> false
    end
  end

  defp absolute_uri?(_value), do: false

  defp optional_field?(object, key, valid?) do
    case Map.fetch(object, key) do
      :error -> true
      {:ok, value} -> valid?.(value)
    end
  end

  defp validate_headers(headers, request) do
    with {:ok, version} <- header(headers, "mcp-protocol-version", request),
         :ok <- matching_version(version, request),
         :ok <- supported_version(version, request),
         {:ok, method} <- header(headers, "mcp-method", request),
         :ok <- matching_header(method, request["method"], "Mcp-Method", request) do
      validate_name_header(headers, request)
    end
  end

  defp supported_version(version, request) do
    if version == Server.protocol_version() do
      :ok
    else
      error(400, request, :unsupported_protocol_version, "Unsupported protocol version", %{
        "supported" => Versions.supported(),
        "requested" => version
      })
    end
  end

  defp matching_version(version, %{"params" => %{"_meta" => metadata}} = request) when is_map(metadata) do
    matching_header(version, metadata["io.modelcontextprotocol/protocolVersion"], "MCP-Protocol-Version", request)
  end

  defp matching_version(_version, _notification), do: :ok

  defp validate_name_header(headers, %{"method" => method} = request)
       when method in ["tools/call", "prompts/get", "resources/read"] do
    field = if method == "resources/read", do: "uri", else: "name"
    name = Map.get(Map.get(request, "params", %{}), field)

    with {:ok, encoded} <- header(headers, "mcp-name", request),
         {:ok, decoded} <- decode_name(encoded, request) do
      matching_header(decoded, name, "Mcp-Name", request)
    end
  end

  defp validate_name_header(_headers, _request), do: :ok

  defp decode_name("=?base64?" <> encoded, request) do
    with true <- String.ends_with?(encoded, "?="),
         {:ok, decoded} <- Base.decode64(String.slice(encoded, 0, byte_size(encoded) - 2)),
         true <- String.valid?(decoded) do
      {:ok, decoded}
    else
      _invalid -> error(400, request, :header_mismatch, "Malformed Mcp-Name encoding")
    end
  end

  defp decode_name(name, _request), do: {:ok, name}

  defp header(headers, name, request) do
    case for({^name, value} <- headers, do: value) do
      [value] ->
        if Regex.match?(~r/\A[\x20-\x7E]+\z/, value) do
          {:ok, value}
        else
          error(400, request, :header_mismatch, "Malformed #{name} header")
        end

      _values ->
        error(400, request, :header_mismatch, "Missing or repeated #{name} header")
    end
  end

  defp matching_header(value, value, _name, _request), do: :ok

  defp matching_header(_header, _body, name, request),
    do: error(400, request, :header_mismatch, "Header mismatch: #{name} does not match the request body")

  defp error(status, request, reason, message, data \\ nil),
    do: {:error, status, Response.error(Response.request_id(request), reason, message, data)}
end
