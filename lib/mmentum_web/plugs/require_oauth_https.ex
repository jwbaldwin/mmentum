defmodule MmentumWeb.Plugs.RequireOAuthHTTPS do
  import Plug.Conn

  def init(options), do: options

  def call(conn, _options) do
    case AttestoPhoenix.RequestContext.check_https(conn, conn.private.attesto_phoenix_config) do
      :ok ->
        conn

      {:error, :insecure_transport} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, ~s({"error":"invalid_request","error_description":"HTTPS required"}))
        |> halt()
    end
  end
end
