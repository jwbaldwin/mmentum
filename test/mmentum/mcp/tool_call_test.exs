defmodule Mmentum.MCP.ToolCallTest do
  use MmentumWeb.ConnCase, async: true

  import ExUnit.CaptureLog

  alias Mmentum.Logs.Log
  alias Mmentum.OAuthFixtures
  alias Mmentum.Tools.CreateHabit
  alias Mmentum.Tools.GetHabit
  alias Mmentum.Tools.ManageHabitCompletions
  alias Mmentum.Tools.UpdateHabit

  setup do
    user = Mmentum.AccountsFixtures.user_fixture()
    tokens = OAuthFixtures.tokens(user)
    %{conn: OAuthFixtures.bearer_conn(tokens["access_token"]), user: user}
  end

  for version <- ["2025-11-25", "2026-07-28"] do
    @version version

    test "#{version} adds and removes completions with schema-valid structured output", %{conn: conn, user: user} do
      habit = Mmentum.HabitsFixtures.habit_fixture(%{user: user})
      {:ok, previous} = Mmentum.Habits.record_completion(user, habit.id)

      output =
        conn
        |> call_tool(@version, %{
          "name" => "manage_habit_completions",
          "arguments" => %{
            "add" => [%{"habit_id" => habit.id, "completed_at" => "2026-10-08T18:30:00-04:00"}],
            "remove" => [previous.id]
          }
        })
        |> assert_habit_output(ManageHabitCompletions)

      assert [%{"habit_id" => id, "completed_at" => "2026-10-08T22:30:00Z"}] = output["added"]
      assert id == habit.id
      assert [%{"id" => removed_id}] = output["removed"]
      assert removed_id == previous.id
      refute Mmentum.Repo.get(Log, removed_id)
    end

    test "#{version} invalid completion batches are tool errors without writes", %{conn: conn, user: user} do
      habit = Mmentum.HabitsFixtures.habit_fixture(%{user: user})

      for arguments <- [%{}, %{"add" => [%{"habit_id" => habit.id}], "remove" => [9_223_372_036_854_775_807]}] do
        response =
          conn
          |> call_tool(@version, %{"name" => "manage_habit_completions", "arguments" => arguments})
          |> json_response(200)

        assert response["result"]["isError"]
        refute Map.has_key?(response["result"], "structuredContent")
      end

      assert Mmentum.Repo.aggregate(Log, :count) == 0
    end

    test "#{version} creates, updates and gets a habit through authenticated tool calls", %{conn: conn, user: user} do
      created =
        conn
        |> call_tool(@version, %{"name" => "create_habit", "arguments" => %{"name" => "Read", "min_completions" => 1}})
        |> assert_habit_output(CreateHabit)

      id = created["habit"]["id"]
      assert Mmentum.Habits.get_habit!(user, id).name == "Read"
      assert created["habit"]["current_completions"] == 0
      assert created["time_zone"] == "Etc/UTC"

      updated =
        conn
        |> call_tool(@version, %{
          "name" => "update_habit",
          "arguments" => %{"habit_id" => id, "fields" => %{"why_it_matters" => "Learn", "periodicity" => "day"}}
        })
        |> assert_habit_output(UpdateHabit)

      assert updated["habit"]["why_it_matters"] == "Learn"
      assert updated["habit"]["periodicity"] == "day"

      fetched =
        conn
        |> call_tool(@version, %{"name" => "get_habit", "arguments" => %{"habit_id" => id}})
        |> assert_habit_output(GetHabit)

      assert fetched == updated
    end

    test "#{version} reports write validation and ownership failures as tool errors", %{conn: conn} do
      foreign = Mmentum.HabitsFixtures.habit_fixture()

      for params <- [
            %{
              "name" => "create_habit",
              "arguments" => %{"name" => "Read", "min_completions" => 3, "max_completions" => 2}
            },
            %{"name" => "get_habit", "arguments" => %{"habit_id" => foreign.id}},
            %{"name" => "update_habit", "arguments" => %{"habit_id" => foreign.id, "fields" => %{"name" => "Changed"}}}
          ] do
        response = conn |> call_tool(@version, params) |> json_response(200)
        assert response["result"]["isError"]
        refute Map.has_key?(response["result"], "structuredContent")
      end
    end

    test "#{version} read-only OAuth grants cannot create or update habits", %{user: user} do
      tokens = OAuthFixtures.tokens(user, %{"scope" => "mmentum:read"})
      conn = OAuthFixtures.bearer_conn(tokens["access_token"])

      for name <- ["create_habit", "update_habit", "manage_habit_completions"] do
        response = conn |> call_tool(@version, %{"name" => name, "arguments" => %{}}) |> json_response(200)
        assert response["result"]["isError"]
        assert hd(response["result"]["content"])["text"] =~ "permission"
      end
    end

    test "#{version} executes the owned habit query and returns structured and text results", %{conn: conn, user: user} do
      habit = Mmentum.HabitsFixtures.habit_fixture(%{user: user})
      Mmentum.HabitsFixtures.habit_fixture()

      {result, log} =
        with_log(fn ->
          conn |> call_tool(@version, %{"name" => "list_habits"}) |> json_response(200) |> Map.fetch!("result")
        end)

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

      assert log =~ "mcp_request_completed"
      assert log =~ "mcp_method=tools/call"
      assert log =~ "mcp_tool=list_habits"
      assert log =~ "mcp_protocol=#{@version}"
      assert log =~ "mcp_client=unknown"
      assert log =~ "mcp_outcome=success"
      assert log =~ ~r/mcp_duration_us=\d+/
      refute log =~ habit.name
      refute log =~ user.email
    end

    test "#{version} distinguishes malformed calls from tool input errors", %{conn: conn} do
      for params <- [%{}, %{"name" => 1}, %{"name" => "list_habits", "arguments" => []}] do
        assert %{"error" => %{"code" => -32_602}} = conn |> call_tool(@version, params) |> json_response(400)
      end

      {result, log} =
        with_log(fn ->
          conn
          |> call_tool(@version, %{"name" => "list_habits", "arguments" => %{"user_id" => 1}})
          |> json_response(200)
        end)

      assert result["result"]["isError"]
      refute Map.has_key?(result["result"], "structuredContent")
      assert log =~ "mcp_outcome=tool_error"
    end
  end

  defp assert_habit_output(conn, tool) do
    response = conn |> json_response(200) |> Map.fetch!("result")
    refute response["isError"]
    assert [%{"type" => "text", "text" => text}] = response["content"]
    assert Jason.decode!(text) == response["structuredContent"]
    schema = tool.output_schema() |> Jason.encode!() |> Jason.decode!() |> Zoi.from_json_schema()
    assert {:ok, _habit} = Zoi.parse(schema, response["structuredContent"])
    response["structuredContent"]
  end

  defp call_tool(conn, version, params) do
    tool_name =
      case params["name"] do
        name when is_binary(name) -> name
        _ -> "list_habits"
      end

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
    |> put_req_header("mcp-name", tool_name)
    |> post(
      "https://localhost:4443/mcp",
      Jason.encode!(%{"jsonrpc" => "2.0", "id" => 1, "method" => "tools/call", "params" => params})
    )
  end
end
