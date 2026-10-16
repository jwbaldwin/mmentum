defmodule Mmentum.MCP.UsageTest do
  use MmentumWeb.ConnCase, async: false

  import ExUnit.CaptureLog

  alias Mmentum.MCP.Usage
  alias Mmentum.MCP.Versions.V2025_11_25.Server
  alias Mmentum.OAuthFixtures

  setup do
    clients = Application.fetch_env!(:mmentum, :oauth_clients)
    Application.put_env(:mmentum, :oauth_clients, Enum.map(clients, &Map.put(&1, "setup_client", "opencode")))
    level = Logger.level()

    on_exit(fn ->
      Application.put_env(:mmentum, :oauth_clients, clients)
      Logger.configure(level: level)
    end)

    user = Mmentum.AccountsFixtures.user_fixture()
    tokens = OAuthFixtures.tokens(user)
    Logger.configure(level: :info)
    %{conn: OAuthFixtures.bearer_conn(tokens["access_token"]), user: user, tokens: tokens}
  end

  for version <- ["2025-11-25", "2026-07-28"] do
    @version version

    test "#{version} logs authenticated registered client and real tool outcomes", %{
      conn: conn,
      user: user,
      tokens: tokens
    } do
      habit = Mmentum.HabitsFixtures.habit_fixture(%{user: user, name: "private-habit-marker"})

      log =
        usage_log(fn ->
          response = conn |> send_mcp(@version, "tools/call", %{"name" => "list_habits"}) |> json_response(200)
          assert response["result"]["isError"] == false
          assert [%{"id" => id}] = response["result"]["structuredContent"]["habits"]
          assert id == habit.id
        end)

      assert log =~ "mcp_client=opencode"
      assert log =~ "mcp_method=tools/call"
      assert log =~ "mcp_tool=list_habits"
      assert log =~ "mcp_protocol=#{@version}"
      assert log =~ "mcp_outcome=success"
      assert Regex.match?(~r/mcp_duration_us=\d+/, log)
      assert length(Regex.scan(~r/mcp_request_completed/, log)) == 1

      for private <- [
            habit.name,
            user.email,
            tokens["access_token"],
            "structuredContent",
            "oauth-test",
            "spoofed-client-marker"
          ] do
        refute log =~ private
      end

      log =
        usage_log(fn ->
          response =
            conn
            |> send_mcp(@version, "tools/call", %{
              "name" => "list_habits",
              "arguments" => %{"private-argument-marker" => "private-value-marker"}
            })
            |> json_response(200)

          assert response["result"]["isError"]
        end)

      assert log =~ "mcp_outcome=tool_error"
      refute log =~ "private-argument-marker"
      refute log =~ "private-value-marker"
      refute log =~ "This tool takes no arguments"
    end

    test "#{version} distinguishes discovery and safely logs unknown tools and methods", %{conn: conn} do
      method = if @version == "2025-11-25", do: "initialize", else: "server/discover"

      log = usage_log(fn -> assert send_mcp(conn, @version, method).status == 200 end)
      assert log =~ "mcp_method=#{method}"
      assert log =~ "mcp_tool=none"
      assert log =~ "mcp_outcome=success"
      refute log =~ "spoofed-client-marker"

      for {method, params} <- [
            {"tools/call", %{"name" => "private-tool-marker"}},
            {"private-method-marker", %{}}
          ] do
        log =
          usage_log(fn ->
            response = send_mcp(conn, @version, method, params)
            assert Jason.decode!(response.resp_body)["error"]
          end)

        assert log =~ "mcp_outcome=protocol_error"
        assert log =~ if(method == "tools/call", do: "mcp_tool=unknown", else: "mcp_method=unknown")
        refute log =~ "private-tool-marker"
        refute log =~ "private-method-marker"
        refute log =~ "Handling"
      end
    end
  end

  test "malformed calls are protocol errors rather than successful tool usage", %{conn: conn} do
    log =
      usage_log(fn ->
        assert conn
               |> send_mcp("2026-07-28", "tools/call", %{"name" => "list_habits", "arguments" => []})
               |> json_response(400)
      end)

    assert log =~ "mcp_method=tools/call"
    assert log =~ "mcp_outcome=protocol_error"
    refute log =~ "mcp_outcome=success"
  end

  test "unmapped and unsupported registered setup keys stay unknown despite clientInfo", %{conn: conn} do
    clients = Application.fetch_env!(:mmentum, :oauth_clients)

    for key <- [nil, "private-client-marker"] do
      Application.put_env(:mmentum, :oauth_clients, Enum.map(clients, &Map.put(&1, "setup_client", key)))
      log = usage_log(fn -> assert send_mcp(conn, "2026-07-28", "tools/list").status == 200 end)
      assert log =~ "mcp_client=unknown"
      refute log =~ "private-client-marker"
      refute log =~ "spoofed-client-marker"
      refute log =~ "oauth-test"
    end
  end

  test "exceptions emit only a safe outcome and keep their original stacktrace", %{user: user} do
    context = %{user: %{user | time_zone: "private-exception-marker"}, scopes: [:read], now: DateTime.utc_now()}
    request = %{"jsonrpc" => "2.0", "id" => 1, "method" => "tools/call", "params" => %{"name" => "list_habits"}}
    headers = [{"mcp-protocol-version", "2025-11-25"}]

    log =
      usage_log(fn ->
        try do
          Usage.invoke(Server, request, headers, context, %{"client_id" => "unregistered-private-client"})
          flunk("expected the original time-zone exception")
        rescue
          error in ArgumentError ->
            assert error.message =~ "private-exception-marker"
            assert [{DateTime, :shift_zone!, _, _} | _] = __STACKTRACE__
        end
      end)

    assert log =~ "mcp_outcome=exception"
    assert log =~ "mcp_client=unknown"
    refute log =~ "private-exception-marker"
    refute log =~ "unregistered-private-client"
    refute log =~ "ArgumentError"
  end

  defp usage_log(fun) do
    capture_log(
      [level: :info, format: "$message $metadata\n", metadata: Application.fetch_env!(:logger, :console)[:metadata]],
      fun
    )
  end

  defp send_mcp(conn, version, method, params \\ %{}) do
    params =
      if version == "2026-07-28" do
        Map.put(params, "_meta", %{
          "io.modelcontextprotocol/protocolVersion" => version,
          "io.modelcontextprotocol/clientCapabilities" => %{},
          "io.modelcontextprotocol/clientInfo" => %{"name" => "spoofed-client-marker", "version" => "1"}
        })
      else
        Map.merge(
          %{
            "protocolVersion" => version,
            "capabilities" => %{},
            "clientInfo" => %{"name" => "spoofed-client-marker", "version" => "1"}
          },
          params
        )
      end

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("accept", "application/json, text/event-stream")
      |> put_req_header("mcp-protocol-version", version)
      |> put_req_header("mcp-method", method)

    conn = if method == "tools/call", do: put_req_header(conn, "mcp-name", params["name"]), else: conn

    post(
      conn,
      "https://localhost:4443/mcp",
      Jason.encode!(%{"jsonrpc" => "2.0", "id" => 1, "method" => method, "params" => params})
    )
  end
end
