defmodule Mmentum.MCP.ToolCallTest do
  use MmentumWeb.ConnCase, async: true

  alias Mmentum.OAuthFixtures

  setup do
    user = Mmentum.AccountsFixtures.user_fixture()
    tokens = OAuthFixtures.tokens(user)
    %{conn: OAuthFixtures.bearer_conn(tokens["access_token"]), user: user}
  end

  for version <- ["2025-11-25", "2026-07-28"] do
    @version version

    test "#{version} executes the owned habit query and returns structured and text results", %{conn: conn, user: user} do
      habit = Mmentum.HabitsFixtures.habit_fixture(%{user: user})
      Mmentum.HabitsFixtures.habit_fixture()
      result = conn |> call_tool(@version, %{"name" => "list_habits"}) |> json_response(200) |> Map.fetch!("result")
      assert result["isError"] == false
      assert %{"habits" => [%{"id" => id, "current_completions" => 0}]} = result["structuredContent"]
      assert id == habit.id
      assert result["structuredContent"]["time_zone"] == "Etc/UTC"
      assert [%{"type" => "text", "text" => text}] = result["content"]
      assert Jason.decode!(text) == result["structuredContent"]
      schema = Mmentum.Tools.ListHabits.output_schema() |> Jason.encode!() |> Jason.decode!()
      assert {:ok, _habits} = schema |> Zoi.from_json_schema() |> Zoi.parse(result["structuredContent"])
      assert schema["additionalProperties"] == false
      assert "max_completions" in schema["properties"]["habits"]["items"]["required"]
    end

    test "#{version} distinguishes malformed calls from tool input errors", %{conn: conn} do
      for params <- [%{}, %{"name" => 1}, %{"name" => "list_habits", "arguments" => []}] do
        assert %{"error" => %{"code" => -32_602}} = conn |> call_tool(@version, params) |> json_response(400)
      end

      result =
        conn |> call_tool(@version, %{"name" => "list_habits", "arguments" => %{"user_id" => 1}}) |> json_response(200)

      assert result["result"]["isError"]
      refute Map.has_key?(result["result"], "structuredContent")
    end
  end

  defp call_tool(conn, version, params) do
    params =
      if version == "2026-07-28" do
        Map.put(params, "_meta", %{
          "io.modelcontextprotocol/protocolVersion" => version,
          "io.modelcontextprotocol/clientCapabilities" => %{}
        })
      else
        params
      end

    conn
    |> put_req_header("content-type", "application/json")
    |> put_req_header("accept", "application/json, text/event-stream")
    |> put_req_header("mcp-protocol-version", version)
    |> put_req_header("mcp-method", "tools/call")
    |> put_req_header("mcp-name", "list_habits")
    |> post(
      "https://localhost:4443/mcp",
      Jason.encode!(%{"jsonrpc" => "2.0", "id" => 1, "method" => "tools/call", "params" => params})
    )
  end
end
