defmodule Mmentum.ToolsTest do
  use Mmentum.DataCase, async: true

  alias Mmentum.Tools

  test "scope checks run before a tool executes" do
    assert {:error, :insufficient_scope, _} = Tools.execute("list_habits", %{scopes: []}, %{})
    assert {:error, :tool_not_found} = Tools.execute("missing_tool", %{}, %{})
  end

  test "lists owned habits using local current-period activity without capping counts" do
    user = Mmentum.AccountsFixtures.user_fixture(%{time_zone: "America/New_York"})
    Mmentum.HabitsFixtures.habit_fixture()
    habit = Mmentum.HabitsFixtures.habit_fixture(%{user: user, periodicity: :day, min_completions: 1})

    for time <- [~N[2026-10-04 03:59:59], ~N[2026-10-04 04:00:00], ~N[2026-10-05 03:59:59], ~N[2026-10-05 04:00:00]] do
      Mmentum.Repo.insert!(%Mmentum.Logs.Log{user_id: user.id, habit_id: habit.id, inserted_at: time, updated_at: time})
    end

    context = %{user: user, scopes: [:read], now: ~U[2026-10-05 02:00:00Z]}
    assert {:ok, %{habits: [listed], time_zone: "America/New_York"}} = Tools.execute("list_habits", context, %{})
    assert listed.id == habit.id
    assert listed.current_completions == 2
    assert listed.periodicity == "day"
    assert listed.max_completions == nil
  end

  test "rejects arguments, but an empty account succeeds" do
    user = Mmentum.AccountsFixtures.user_fixture(%{time_zone: "Etc/UTC"})
    context = %{user: user, scopes: [:read], now: ~U[2026-10-05 02:00:00Z]}
    assert {:ok, %{habits: [], time_zone: "Etc/UTC"}} = Tools.execute("list_habits", context, %{})
    assert {:error, :invalid_arguments, _} = Tools.execute("list_habits", context, %{"user_id" => user.id})
  end

  test "an unset time zone uses UTC calendar boundaries and labels the result" do
    user = Mmentum.AccountsFixtures.user_fixture()
    habit = Mmentum.HabitsFixtures.habit_fixture(%{user: user, periodicity: :day})

    for time <- [~N[2026-10-04 23:59:59], ~N[2026-10-05 00:00:00]] do
      Mmentum.Repo.insert!(%Mmentum.Logs.Log{user_id: user.id, habit_id: habit.id, inserted_at: time, updated_at: time})
    end

    context = %{user: %{user | time_zone: nil}, scopes: [:read], now: ~U[2026-10-05 02:00:00Z]}

    assert {:ok, %{habits: [%{current_completions: 1}], time_zone: "Etc/UTC"}} =
             Tools.execute("list_habits", context, %{})
  end

  test "OAuth scope conversion only grants recognized permissions" do
    assert Mmentum.Tools.Scope.from_oauth(["mmentum:read", "mmentum:write", "openid"]) == [:read, :write]
    assert Mmentum.Tools.Scope.from_oauth(["mmentum:admin"]) == []
    assert {:error, :insufficient_scope, _} = Tools.execute("list_habits", %{scopes: [:write]}, %{})
  end
end
