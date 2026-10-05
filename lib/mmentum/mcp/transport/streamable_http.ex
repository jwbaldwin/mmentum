defmodule Mmentum.MCP.Transport.StreamableHTTP do
  @moduledoc "Owns HTTP checks and JSON decoding, then delegates to one MCP version"

  @behaviour Plug

  import Plug.Conn
  alias Mmentum.MCP.Versions

  @impl Plug
  def init(options), do: options

  @impl Plug
  def call(conn, options) do
    allowed_origins = Keyword.get_lazy(options, :allowed_origins, fn -> [conn.private.phoenix_endpoint.url()] end)

    case validate_origin(conn, allowed_origins) do
      :ok -> route(conn)
      {:error, status, reason, message} -> send_error(conn, status, reason, message)
    end
  end

  defp route(%{path_info: [_ | _]} = conn), do: send_json(conn, 404, %{"error" => "Not found"})

  defp route(%{method: "POST"} = conn) do
    with :ok <- validate_content_type(conn),
         :ok <- validate_accept(conn) do
      read_request(conn)
    else
      {:error, status, reason, message} -> send_error(conn, status, reason, message)
    end
  end

  defp route(conn) do
    conn |> put_resp_header("allow", "POST") |> send_json(405, %{"error" => "Method not allowed"})
  end

  defp read_request(conn) do
    case read_body(conn, length: 1_000_000) do
      {:ok, body, conn} ->
        case Jason.decode(body) do
          {:ok, request} ->
            {server, _response} = Versions.select(request, conn.req_headers)

            context = %{
              user: conn.assigns.current_user,
              scopes: conn.assigns.attesto_mcp_scopes,
              now: DateTime.utc_now()
            }

            case server.handle(request, conn.req_headers, context) do
              {202, nil} -> conn |> send_resp(202, "") |> halt()
              {status, response} -> send_json(conn, status, response)
            end

          {:error, _reason} ->
            send_error(conn, 400, :parse_error, "Parse error")
        end

      {:more, _body, conn} ->
        send_error(conn, 413, :invalid_request, "Request too large")

      {:error, _reason} ->
        send_error(conn, 400, :invalid_request, "Could not read request body")
    end
  end

  defp validate_origin(conn, allowed_origins) do
    case get_req_header(conn, "origin") do
      [] ->
        :ok

      [origin] ->
        if valid_origin?(origin, allowed_origins),
          do: :ok,
          else: {:error, 403, :invalid_request, "Forbidden origin"}

      _origins ->
        {:error, 403, :invalid_request, "Forbidden origin"}
    end
  end

  defp valid_origin?(origin, allowed_origins) do
    case parse_origin(origin) do
      {:ok, parsed} -> Enum.any?(allowed_origins, &(parse_origin(&1) == {:ok, parsed}))
      :error -> false
    end
  end

  defp parse_origin(origin) do
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
      _invalid -> {:error, 415, :invalid_request, "Content-Type must be application/json"}
    end
  end

  defp validate_accept(conn) do
    if accepts?(conn, "application", "json") and accepts?(conn, "text", "event-stream"),
      do: :ok,
      else: {:error, 406, :invalid_request, "Accept must include application/json and text/event-stream"}
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

  defp send_error(conn, status, reason, message) do
    {_server, response} = Versions.select(nil, conn.req_headers)
    send_json(conn, status, response.error(nil, reason, message))
  end

  defp send_json(conn, status, body) do
    conn |> put_resp_content_type("application/json") |> send_resp(status, Jason.encode!(body)) |> halt()
  end
end
