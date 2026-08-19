defmodule Mmentum.MCP.Transport.StreamableHTTPTest do
  use MmentumWeb.ConnCase, async: true

  test "POST /mcp reaches the reserved Streamable HTTP boundary", %{conn: conn} do
    conn = post(conn, ~p"/mcp", %{})

    assert json_response(conn, 501) == %{
             "error" => "MCP protocol handling is not implemented"
           }
  end
end
