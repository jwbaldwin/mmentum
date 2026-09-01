defmodule Mmentum.MCP.Transport.StreamableHTTP do
  @moduledoc """
  Reads MCP requests from HTTP, checks that they are valid, and writes HTTP replies

  Validates the message before comparing routing headers or calling `MCP.Server`
  The server owns MCP operations; this Plug owns HTTP status codes and JSON-RPC replies
  """

  @behaviour Plug

  import Plug.Conn

  alias Mmentum.MCP.JSONRPC
  alias Mmentum.MCP.Server

  @impl Plug
  def init(options), do: options

  @impl Plug
  def call(conn, options) do
    allowed_origins = Keyword.get_lazy(options, :allowed_origins, fn -> [conn.private.phoenix_endpoint.url()] end)

    case validate_origin(conn, allowed_origins) do
      :ok -> route(conn)
      {:error, status, response} -> send_json(conn, status, response)
    end
  end

  defp route(%{path_info: [_ | _]} = conn), do: send_json(conn, 404, %{"error" => "Not found"})

  defp route(%{method: "POST"} = conn) do
    with :ok <- validate_content_type(conn),
         :ok <- validate_accept(conn) do
      read_request(conn)
    else
      {:error, status, response} -> send_json(conn, status, response)
    end
  end

  defp route(conn) do
    conn |> put_resp_header("allow", "POST") |> send_json(405, %{"error" => "Method not allowed"})
  end

  defp read_request(conn) do
    case read_body(conn, length: 1_000_000) do
      {:ok, body, conn} ->
        case Jason.decode(body) do
          {:ok, request} -> process_request(conn, request)
          {:error, _reason} -> send_json(conn, 400, JSONRPC.error(nil, :parse_error, "Parse error"))
        end

      {:more, _body, conn} ->
        send_json(conn, 413, JSONRPC.error(nil, :invalid_request, "Request too large"))

      {:error, _reason} ->
        send_json(conn, 400, JSONRPC.error(nil, :invalid_request, "Could not read request body"))
    end
  end

  defp process_request(conn, request) do
    with :ok <- validate_message(request),
         :ok <- validate_metadata(request),
         :ok <- validate_headers(conn, request) do
      if Map.has_key?(request, "id") do
        respond(conn, request, Server.handle(request))
      else
        conn |> send_resp(202, "") |> halt()
      end
    else
      {:error, status, response} -> send_json(conn, status, response)
    end
  end

  defp validate_message(%{"jsonrpc" => "2.0", "method" => method} = request) when is_binary(method) do
    valid_id? = not Map.has_key?(request, "id") or not is_nil(JSONRPC.response_id(request))

    cond do
      not valid_id? -> error(400, request, :invalid_request, "Request ID must be a string or integer")
      not is_map(Map.get(request, "params", %{})) -> error(400, request, :invalid_params, "params must be an object")
      true -> :ok
    end
  end

  defp validate_message(request), do: error(400, request, :invalid_request, "Invalid Request")

  defp validate_metadata(%{"id" => _id} = request) do
    case request do
      %{
        "params" => %{
          "_meta" =>
            %{
              "io.modelcontextprotocol/protocolVersion" => version,
              "io.modelcontextprotocol/clientCapabilities" => capabilities
            } = metadata
        }
      }
      when is_binary(version) and is_map(capabilities) ->
        case Map.fetch(metadata, "io.modelcontextprotocol/clientInfo") do
          :error -> :ok
          {:ok, %{"name" => name, "version" => version}} when is_binary(name) and is_binary(version) -> :ok
          _invalid -> error(400, request, :invalid_params, "Invalid clientInfo")
        end

      _invalid ->
        error(400, request, :invalid_params, "Invalid or missing request metadata")
    end
  end

  defp validate_metadata(_notification), do: :ok

  defp validate_headers(conn, request) do
    with {:ok, version} <- header(conn, "mcp-protocol-version", request),
         :ok <- supported_version(version, request),
         :ok <- matching_version(version, request),
         {:ok, method} <- header(conn, "mcp-method", request),
         :ok <- matching_header(method, request["method"], "Mcp-Method", request) do
      validate_name_header(conn, request)
    end
  end

  defp supported_version(version, request) do
    if version == Server.protocol_version() do
      :ok
    else
      error(400, request, :unsupported_protocol_version, "Unsupported protocol version", %{
        "supported" => [Server.protocol_version()],
        "requested" => version
      })
    end
  end

  defp matching_version(version, %{"params" => %{"_meta" => metadata}} = request) when is_map(metadata) do
    matching_header(version, metadata["io.modelcontextprotocol/protocolVersion"], "MCP-Protocol-Version", request)
  end

  defp matching_version(_version, _notification), do: :ok

  defp validate_name_header(conn, %{"method" => method} = request)
       when method in ["tools/call", "prompts/get", "resources/read"] do
    field = if method == "resources/read", do: "uri", else: "name"
    name = Map.get(Map.get(request, "params", %{}), field)

    with {:ok, encoded} <- header(conn, "mcp-name", request),
         {:ok, decoded} <- decode_name(encoded, request) do
      matching_header(decoded, name, "Mcp-Name", request)
    end
  end

  defp validate_name_header(_conn, _request), do: :ok

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

  defp header(conn, name, request) do
    case get_req_header(conn, name) do
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

  defp validate_origin(conn, allowed_origins) do
    case get_req_header(conn, "origin") do
      [] ->
        :ok

      [origin] ->
        if valid_origin?(origin, allowed_origins),
          do: :ok,
          else: error(403, nil, :invalid_request, "Forbidden origin")

      _origins ->
        error(403, nil, :invalid_request, "Forbidden origin")
    end
  end

  defp valid_origin?(origin, allowed_origins) do
    case parse_origin(origin) do
      {:ok, parsed} -> Enum.any?(allowed_origins, &(parse_origin(&1) == {:ok, parsed}))
      :error -> false
    end
  end

  defp parse_origin(origin) do
    # URI.parse is permissive, so validate the authority before comparing its fields
    if Regex.match?(~r{\Ahttps?://(?:\[[0-9a-fA-F:.]+\]|[a-zA-Z0-9.-]+)(?::[0-9]+)?\z}, origin) do
      uri = URI.parse(origin)
      if uri.port in 1..65_535, do: {:ok, {uri.scheme, String.downcase(uri.host), uri.port}}, else: :error
    else
      :error
    end
  end

  defp validate_content_type(conn) do
    with [content_type] <- get_req_header(conn, "content-type"),
         {:ok, "application", "json", _params} <- Plug.Conn.Utils.content_type(content_type) do
      :ok
    else
      _invalid -> error(415, nil, :invalid_request, "Content-Type must be application/json")
    end
  end

  defp validate_accept(conn) do
    if accepts?(conn, "application", "json") and accepts?(conn, "text", "event-stream"),
      do: :ok,
      else: error(406, nil, :invalid_request, "Accept must include application/json and text/event-stream")
  end

  defp accepts?(conn, type, subtype) do
    conn
    |> get_req_header("accept")
    |> Enum.flat_map(&String.split(&1, ","))
    |> Enum.any?(fn media_range ->
      case Plug.Conn.Utils.media_type(media_range) do
        {:ok, ^type, ^subtype, params} -> positive_quality?(params["q"])
        _other -> false
      end
    end)
  end

  defp positive_quality?(nil), do: true

  defp positive_quality?(quality) do
    case Float.parse(quality) do
      {value, ""} -> value > 0 and value <= 1
      _invalid -> false
    end
  end

  defp respond(conn, request, {:ok, result}), do: send_json(conn, 200, JSONRPC.result(request["id"], result))

  defp respond(conn, request, {:error, :method_not_found, message}),
    do: send_json(conn, 404, JSONRPC.error(request["id"], :method_not_found, message))

  defp error(status, request, reason, message, data \\ nil),
    do: {:error, status, JSONRPC.error(JSONRPC.response_id(request), reason, message, data)}

  defp send_json(conn, status, body) do
    conn |> put_resp_content_type("application/json") |> send_resp(status, Jason.encode!(body)) |> halt()
  end
end
