defmodule Mmentum.MCP.Transport.StreamableHTTP do
  @moduledoc """
  Owns Streamable HTTP request and response handling for the MCP endpoint
  """

  @behaviour Plug

  import Plug.Conn

  alias Mmentum.MCP.Server

  @impl Plug
  def init(options), do: options

  @impl Plug
  def call(conn, _options) do
    case Server.handle() do
      {:error, :not_implemented} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(501, Jason.encode!(%{"error" => "MCP protocol handling is not implemented"}))
    end
  end
end
