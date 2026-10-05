defmodule Mmentum.MCP.Versions.V2025_11_25Test do
  use MmentumWeb.ConnCase, async: true

  alias Mmentum.OAuthFixtures

  setup do
    user = Mmentum.AccountsFixtures.user_fixture()
    tokens = OAuthFixtures.tokens(user)
    %{conn: OAuthFixtures.bearer_conn(tokens["access_token"])}
  end

  test "initializes, acknowledges readiness, pings and lists tools without a stored session", %{conn: conn} do
    initialized = send_legacy(conn, initialize(), version: nil)

    assert %{
             "id" => 1,
             "result" => %{
               "protocolVersion" => "2025-11-25",
               "capabilities" => %{"tools" => %{}},
               "serverInfo" => %{"name" => "mmentum", "version" => version}
             }
           } = json_response(initialized, 200)

    assert is_binary(version)
    assert get_resp_header(initialized, "mcp-session-id") == []

    ready = send_legacy(conn, %{"jsonrpc" => "2.0", "method" => "notifications/initialized"})
    assert response(ready, 202) == ""

    assert %{"id" => "ping", "result" => %{}} = json_response(send_legacy(conn, request("ping", "ping")), 200)
    assert %{"id" => 2, "result" => result} = json_response(send_legacy(conn, request("tools/list", 2)), 200)
    assert result == %{"tools" => []}
  end

  test "advertises both versions and keeps their results separate for the same caller", %{conn: conn} do
    assert json_response(send_legacy(conn, request("tools/list", 1)), 200)["result"] == %{"tools" => []}

    modern =
      Map.put(request("server/discover", 2), "params", %{
        "_meta" => %{
          "io.modelcontextprotocol/protocolVersion" => "2026-07-28",
          "io.modelcontextprotocol/clientCapabilities" => %{}
        }
      })

    result =
      conn
      |> put_req_header("mcp-method", "server/discover")
      |> send_legacy(modern, version: "2026-07-28")
      |> json_response(200)
      |> Map.fetch!("result")

    assert "2025-11-25" in result["supportedVersions"]
    assert "2026-07-28" in result["supportedVersions"]
    assert result["resultType"] == "complete"
    assert json_response(send_legacy(conn, request("tools/list", 3)), 200)["result"] == %{"tools" => []}
  end

  test "offers the supported legacy version when initialization requests another version", %{conn: conn} do
    request = put_in(initialize(), ["params", "protocolVersion"], "2025-03-26")
    assert json_response(send_legacy(conn, request, version: nil), 200)["result"]["protocolVersion"] == "2025-11-25"
  end

  test "legacy operations do not require modern method or name headers", %{conn: conn} do
    request = Map.put(request("tools/call", 2), "params", %{"name" => "missing_tool", "arguments" => %{}})
    assert %{"id" => 2, "error" => %{"code" => -32_602}} = json_response(send_legacy(conn, request), 200)
  end

  test "rejects malformed initialization instead of returning a negotiated version", %{conn: conn} do
    for params <- [
          %{},
          %{
            "protocolVersion" => "2025-11-25",
            "capabilities" => [],
            "clientInfo" => %{"name" => "client", "version" => "1"}
          },
          %{"protocolVersion" => "2025-11-25", "capabilities" => %{}, "clientInfo" => %{"name" => "client"}}
        ] do
      request = Map.put(initialize(), "params", params)
      assert %{"error" => %{"code" => -32_602}} = json_response(send_legacy(conn, request, version: nil), 400)
    end
  end

  test "rejects a version header that conflicts with initialization", %{conn: conn} do
    assert %{"error" => %{"code" => -32_600}} =
             json_response(send_legacy(conn, initialize(), version: "2026-07-28"), 400)
  end

  test "requires a supported explicit version on requests after initialization", %{conn: conn} do
    for version <- [nil, "2025-03-26", "1900-01-01"] do
      assert %{"error" => %{}} = json_response(send_legacy(conn, request("tools/list", 2), version: version), 400)
    end
  end

  test "does not route modern metadata through the weaker legacy header rules", %{conn: conn} do
    request =
      Map.put(request("tools/list", 2), "params", %{
        "_meta" => %{
          "io.modelcontextprotocol/protocolVersion" => "2026-07-28",
          "io.modelcontextprotocol/clientCapabilities" => %{}
        }
      })

    assert %{"error" => %{"code" => -32_020}} = json_response(send_legacy(conn, request), 400)
  end

  test "does not accept legacy-shaped messages declaring the modern version", %{conn: conn} do
    assert %{"error" => %{"code" => -32_602}} =
             json_response(send_legacy(conn, request("tools/list", 2), version: "2026-07-28"), 400)
  end

  test "rejects duplicate version headers", %{conn: conn} do
    conn =
      Plug.Conn.prepend_req_headers(conn, [
        {"mcp-protocol-version", "2025-11-25"},
        {"mcp-protocol-version", "2026-07-28"}
      ])

    assert %{"error" => %{}} = json_response(send_legacy(conn, request("tools/list", 2), version: nil), 400)
  end

  test "rejects invalid cursors and request IDs", %{conn: conn} do
    request = Map.put(request("tools/list", 2), "params", %{"cursor" => []})
    assert %{"id" => 2, "error" => %{"code" => -32_602}} = json_response(send_legacy(conn, request), 400)
    response = json_response(send_legacy(conn, request("tools/list", nil)), 400)
    assert response["error"]["code"] == -32_600
    refute Map.has_key?(response, "id")
  end

  test "legacy requests still require authentication and an allowed Origin", %{conn: conn} do
    assert send_legacy(OAuthFixtures.https_conn(), initialize(), version: nil).status == 401

    assert conn
           |> put_req_header("origin", "https://attacker.example")
           |> send_legacy(initialize(), version: nil)
           |> response(403)
  end

  test "legacy requests still require supported content types", %{conn: conn} do
    response =
      conn
      |> put_req_header("content-type", "text/plain")
      |> put_req_header("accept", "application/json, text/event-stream")
      |> put_req_header("mcp-protocol-version", "2025-11-25")
      |> post("https://localhost:4443/mcp", Jason.encode!(request("tools/list", 2)))

    assert %{"error" => %{}} = json_response(response, 415)
  end

  defp initialize do
    Map.put(request("initialize", 1), "params", %{
      "protocolVersion" => "2025-11-25",
      "capabilities" => %{"roots" => %{"listChanged" => true}},
      "clientInfo" => %{"name" => "legacy-client", "version" => "1"}
    })
  end

  defp request(method, id), do: %{"jsonrpc" => "2.0", "id" => id, "method" => method}

  defp send_legacy(conn, request, options \\ []) do
    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("accept", "application/json, text/event-stream")

    conn =
      case Keyword.get(options, :version, "2025-11-25") do
        nil -> conn
        version -> put_req_header(conn, "mcp-protocol-version", version)
      end

    post(conn, "https://localhost:4443/mcp", Jason.encode!(request))
  end
end
