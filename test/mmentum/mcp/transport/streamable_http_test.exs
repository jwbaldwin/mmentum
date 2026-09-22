defmodule Mmentum.MCP.Transport.StreamableHTTPTest do
  use MmentumWeb.ConnCase, async: true

  setup do
    user = Mmentum.AccountsFixtures.user_fixture()
    tokens = Mmentum.OAuthFixtures.tokens(user)
    %{conn: Mmentum.OAuthFixtures.bearer_conn(tokens["access_token"])}
  end

  test "POST /mcp serves stateless discovery", %{conn: conn} do
    conn = send_mcp(conn, request("server/discover"))

    assert %{
             "id" => 1,
             "result" => %{
               "resultType" => "complete",
               "supportedVersions" => ["2026-07-28"],
               "capabilities" => %{"tools" => %{}},
               "cacheScope" => "public",
               "_meta" => %{"io.modelcontextprotocol/serverInfo" => %{"name" => "mmentum"}}
             }
           } = json_response(conn, 200)
  end

  test "requests can omit optional clientInfo", %{conn: conn} do
    request =
      update_in(request("server/discover"), ["params", "_meta"], &Map.delete(&1, "io.modelcontextprotocol/clientInfo"))

    assert send_mcp(conn, request).status == 200
  end

  test "missing required metadata returns HTTP 400", %{conn: conn} do
    conn = send_mcp(conn, %{request("tools/list") | "params" => %{}})
    assert %{"error" => %{"code" => -32_602}} = json_response(conn, 400)
  end

  test "invalid IDs are rejected rather than accepted as notifications", %{conn: conn} do
    for id <- [nil, true, 1.5, [], %{}] do
      conn = send_mcp(conn, %{request("tools/list") | "id" => id})
      response = json_response(conn, 400)
      assert response["error"]["code"] == -32_600
      refute Map.has_key?(response, "id")
    end
  end

  test "string IDs are returned unchanged", %{conn: conn} do
    conn = send_mcp(conn, %{request("tools/list") | "id" => "coffee"})
    assert json_response(conn, 200)["id"] == "coffee"
  end

  test "malformed optional clientInfo is rejected", %{conn: conn} do
    request = put_in(request("tools/list"), ["params", "_meta", "io.modelcontextprotocol/clientInfo"], [])
    conn = send_mcp(conn, request)
    assert %{"error" => %{"code" => -32_602}} = json_response(conn, 400)
  end

  test "notifications have no response body", %{conn: conn} do
    conn = send_mcp(conn, Map.delete(request("notifications/example"), "id"))
    assert conn.status == 202
    assert conn.resp_body == ""
  end

  test "unknown methods return HTTP 404", %{conn: conn} do
    conn = send_mcp(conn, request("unknown/method"))
    assert %{"id" => 1, "error" => %{"code" => -32_601}} = json_response(conn, 404)
  end

  test "encoded names are decoded before comparing headers", %{conn: conn} do
    request = put_in(request("tools/call"), ["params", "name"], "hello 世界")
    conn = send_mcp(conn, request, name: "=?base64?" <> Base.encode64("hello 世界") <> "?=")
    assert %{"error" => %{"code" => -32_601}} = json_response(conn, 404)
  end

  test "malformed name encodings return a header error", %{conn: conn} do
    request = put_in(request("tools/call"), ["params", "name"], "hello")
    conn = send_mcp(conn, request, name: "=?base64?not-base64?=")
    assert %{"error" => %{"code" => -32_020}} = json_response(conn, 400)
  end

  test "malformed Origin ports are rejected", %{conn: conn} do
    origin = URI.parse(MmentumWeb.Endpoint.url())
    conn = send_mcp(conn, request("tools/list"), origin: "#{origin.scheme}://#{origin.host}:abc")
    assert conn.status == 403
  end

  test "Origin checks also apply to non-POST requests", %{conn: conn} do
    conn = conn |> put_req_header("origin", "https://attacker.example") |> get("https://localhost:4443/mcp")
    assert conn.status == 403
  end

  test "POST /mcp lists the empty tool catalog", %{conn: conn} do
    conn = send_mcp(conn, request("tools/list"), method: "tools/list")

    assert %{"result" => %{"resultType" => "complete", "tools" => []}} =
             json_response(conn, 200)
  end

  test "POST /mcp leaves tool execution unavailable", %{conn: conn} do
    request =
      "tools/call"
      |> request()
      |> put_in(["params", "name"], "missing_tool")
      |> put_in(["params", "arguments"], %{})

    conn = send_mcp(conn, request, name: "missing_tool")

    assert %{"error" => %{"code" => -32_601}} =
             json_response(conn, 404)
  end

  test "POST /mcp rejects a tool name header that differs from the body", %{conn: conn} do
    request =
      "tools/call"
      |> request()
      |> put_in(["params", "name"], "missing_tool")

    conn = send_mcp(conn, request, name: "different_tool")

    assert %{"error" => %{"code" => -32_020}} =
             json_response(conn, 400)
  end

  test "POST /mcp requires the protocol version header", %{conn: conn} do
    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("accept", "application/json, text/event-stream")
      |> put_req_header("mcp-method", "server/discover")
      |> post("https://localhost:4443/mcp", Jason.encode!(request("server/discover")))

    assert %{"id" => 1, "error" => %{"code" => -32_020}} =
             json_response(conn, 400)
  end

  test "POST /mcp rejects a protocol version header that differs from the body", %{conn: conn} do
    request = request("server/discover", "1900-01-01")
    conn = send_mcp(conn, request)

    assert %{"error" => %{"code" => -32_020}} =
             json_response(conn, 400)
  end

  test "POST /mcp rejects an unsupported protocol version", %{conn: conn} do
    version = "1900-01-01"
    conn = send_mcp(conn, request("server/discover", version), protocol_version: version)

    assert %{
             "error" => %{
               "code" => -32_022,
               "data" => %{
                 "supported" => ["2026-07-28"],
                 "requested" => "1900-01-01"
               }
             }
           } = json_response(conn, 400)
  end

  test "POST /mcp allows the configured browser origin", %{conn: conn} do
    conn = send_mcp(conn, request("server/discover"), origin: MmentumWeb.Endpoint.url())

    assert json_response(conn, 200)["result"]["supportedVersions"] == ["2026-07-28"]
  end

  test "POST /mcp rejects foreign browser origins", %{conn: conn} do
    conn = send_mcp(conn, request("server/discover"), origin: "https://attacker.example")

    assert %{"error" => %{"code" => -32_600}} = json_response(conn, 403)
  end

  test "POST /mcp rejects a method header that differs from the body", %{conn: conn} do
    conn = send_mcp(conn, request("tools/list"), method: "tools/call")

    assert %{"error" => %{"code" => -32_020}} =
             json_response(conn, 400)
  end

  test "POST /mcp rejects malformed nested request values without crashing", %{conn: conn} do
    request = %{request("tools/list") | "params" => []}
    conn = send_mcp(conn, request)

    assert %{"error" => %{"code" => -32_602}} =
             json_response(conn, 400)
  end

  test "POST /mcp accepts JSON content type parameters", %{conn: conn} do
    conn =
      send_mcp(conn, request("server/discover"), content_type: "application/json; charset=utf-8")

    assert json_response(conn, 200)["result"]["supportedVersions"] == ["2026-07-28"]
  end

  test "POST /mcp rejects repeated content types", %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept", "application/json, text/event-stream")
      |> put_req_header("mcp-protocol-version", "2026-07-28")
      |> put_req_header("mcp-method", "server/discover")
      |> prepend_req_headers([
        {"content-type", "application/json"},
        {"content-type", "text/plain"}
      ])
      |> post("https://localhost:4443/mcp", request("server/discover"))

    assert %{"error" => %{"code" => -32_600}} =
             json_response(conn, 415)
  end

  test "POST /mcp rejects look-alike JSON content types", %{conn: conn} do
    conn = send_mcp(conn, request("server/discover"), content_type: "application/json-patch+json")

    assert %{"error" => %{"code" => -32_600}} =
             json_response(conn, 415)
  end

  test "POST /mcp rejects disabled response content types", %{conn: conn} do
    conn =
      send_mcp(conn, request("server/discover"), accept: "application/json, text/event-stream; q=0")

    assert %{"error" => %{"code" => -32_600}} = json_response(conn, 406)
  end

  test "POST /mcp requires both supported response content types", %{conn: conn} do
    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("accept", "application/json")
      |> put_req_header("mcp-protocol-version", "2026-07-28")
      |> put_req_header("mcp-method", "server/discover")
      |> post("https://localhost:4443/mcp", request("server/discover"))

    assert %{"error" => %{"code" => -32_600}} = json_response(conn, 406)
  end

  test "the deployed endpoint reports malformed JSON as a JSON-RPC parse error", %{conn: conn} do
    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("accept", "application/json, text/event-stream")
      |> put_req_header("mcp-protocol-version", "2026-07-28")
      |> put_req_header("mcp-method", "server/discover")
      |> post("https://localhost:4443/mcp", "{")

    assert %{"error" => %{"code" => -32_700}} =
             Jason.decode!(conn.resp_body)

    assert conn.status == 400
    refute Map.has_key?(Jason.decode!(conn.resp_body), "id")
  end

  test "JSON-RPC batches are rejected because MCP accepts one request per POST", %{conn: conn} do
    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("accept", "application/json, text/event-stream")
      |> put_req_header("mcp-protocol-version", "2026-07-28")
      |> put_req_header("mcp-method", "server/discover")
      |> post("https://localhost:4443/mcp", Jason.encode!([request("server/discover")]))

    assert %{"error" => %{"code" => -32_600}} =
             Jason.decode!(conn.resp_body)

    assert conn.status == 400
  end

  test "large request bodies are rejected through the router", %{conn: conn} do
    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("accept", "application/json, text/event-stream")
      |> post("https://localhost:4443/mcp", String.duplicate(" ", 1_000_001))

    assert %{"error" => %{"code" => -32_600}} = json_response(conn, 413)
  end

  test "the MCP endpoint also accepts a trailing slash", %{conn: conn} do
    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("accept", "application/json, text/event-stream")
      |> put_req_header("mcp-protocol-version", "2026-07-28")
      |> put_req_header("mcp-method", "tools/list")
      |> post("https://localhost:4443/mcp/", Jason.encode!(request("tools/list")))

    assert json_response(conn, 200)["result"]["tools"] == []
  end

  test "non-POST methods are rejected", %{conn: conn} do
    connections = [get(conn, "https://localhost:4443/mcp"), delete(conn, "https://localhost:4443/mcp")]

    for conn <- connections do
      assert conn.status == 405
      assert get_resp_header(conn, "allow") == ["POST"]
    end
  end

  test "rejects malformed declared capabilities and client details", %{conn: conn} do
    for {key, value} <- [
          {"clientCapabilities", %{"roots" => []}},
          {"clientCapabilities", %{"sampling" => %{"tools" => true}}},
          {"clientCapabilities", %{"elicitation" => %{"form" => nil}}},
          {"clientCapabilities", %{"extensions" => %{"com.example/feature" => []}}},
          {"clientCapabilities", %{"experimental" => %{"feature" => false}}},
          {"clientInfo", %{"name" => "test", "version" => "1", "websiteUrl" => 123}},
          {"clientInfo", %{"name" => "test", "version" => "1", "icons" => [%{"src" => 123}]}},
          {"logLevel", "verbose"},
          {"logLevel", nil}
        ] do
      request = put_in(request("server/discover"), ["params", "_meta", "io.modelcontextprotocol/#{key}"], value)
      assert %{"id" => 1, "error" => %{"code" => -32_602}} = json_response(send_mcp(conn, request), 400)
    end
  end

  test "accepts supported metadata and preserves open extension fields", %{conn: conn} do
    metadata = %{
      "io.modelcontextprotocol/protocolVersion" => "2026-07-28",
      "io.modelcontextprotocol/clientCapabilities" => %{
        "roots" => %{},
        "sampling" => %{"tools" => %{}, "context" => %{}},
        "elicitation" => %{"form" => %{}, "url" => %{}},
        "extensions" => %{"com.example/feature" => %{}},
        "custom" => true
      },
      "io.modelcontextprotocol/clientInfo" => %{
        "name" => "test",
        "version" => "1",
        "websiteUrl" => "https://example.com",
        "icons" => [%{"src" => "data:image/png;base64,AA==", "sizes" => ["any"], "theme" => "dark"}]
      },
      "io.modelcontextprotocol/logLevel" => "warning",
      "com.example/extra" => [1]
    }

    request = put_in(request("tools/list"), ["params", "_meta"], metadata)
    assert json_response(send_mcp(conn, request), 200)["result"]["tools"] == []
  end

  test "rejects non-string pagination cursors", %{conn: conn} do
    for cursor <- [[], %{}, nil, 1, true] do
      request = put_in(request("tools/list"), ["params", "cursor"], cursor)
      assert %{"id" => 1, "error" => %{"code" => -32_602}} = json_response(send_mcp(conn, request), 400)
    end
  end

  defp send_mcp(conn, request, options \\ []) do
    protocol_version = Keyword.get(options, :protocol_version, "2026-07-28")
    method = Keyword.get(options, :method, request["method"])
    content_type = Keyword.get(options, :content_type, "application/json")
    accept = Keyword.get(options, :accept, "application/json, text/event-stream")

    conn =
      conn
      |> put_req_header("content-type", content_type)
      |> put_req_header("accept", accept)
      |> put_req_header("mcp-protocol-version", protocol_version)
      |> put_req_header("mcp-method", method)

    conn =
      case Keyword.fetch(options, :name) do
        {:ok, name} -> put_req_header(conn, "mcp-name", name)
        :error -> conn
      end

    conn =
      case Keyword.fetch(options, :origin) do
        {:ok, origin} -> put_req_header(conn, "origin", origin)
        :error -> conn
      end

    post(conn, "https://localhost:4443/mcp", Jason.encode!(request))
  end

  defp request(method, version \\ "2026-07-28") do
    %{
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => method,
      "params" => %{
        "_meta" => %{
          "io.modelcontextprotocol/protocolVersion" => version,
          "io.modelcontextprotocol/clientInfo" => %{
            "name" => "mmentum-test",
            "version" => "1.0.0"
          },
          "io.modelcontextprotocol/clientCapabilities" => %{}
        }
      }
    }
  end
end
