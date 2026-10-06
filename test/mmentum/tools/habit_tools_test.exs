defmodule Mmentum.Tools.HabitToolsTest do
  use Mmentum.DataCase, async: true

  import Mmentum.AccountsFixtures
  import Mmentum.HabitsFixtures

  alias Mmentum.Habits
  alias Mmentum.Habits.Habit
  alias Mmentum.Logs.Log
  alias Mmentum.Repo
  alias Mmentum.Tools

  setup do
    user = user_fixture(%{time_zone: "America/New_York"})
    %{user: user, context: %{user: user, scopes: [:read, :write], now: ~U[2026-10-05 02:00:00Z]}}
  end

  test "catalog publishes the four tools with distinct read and write permissions" do
    definitions = Map.new(Tools.definitions(), &{&1["name"], &1})
    assert Enum.sort(Map.keys(definitions)) == ~w(create_habit get_habit list_habits update_habit)
    assert definitions["get_habit"]["annotations"]["readOnlyHint"]
    refute definitions["create_habit"]["annotations"]["idempotentHint"]
    assert definitions["update_habit"]["annotations"]["idempotentHint"]

    for name <- ~w(create_habit update_habit) do
      assert {:error, :insufficient_scope, _} = Tools.execute(name, %{scopes: [:read]}, %{})
    end

    assert {:error, :insufficient_scope, _} = Tools.execute("get_habit", %{scopes: [:write]}, %{})
  end

  test "create assigns ownership and returns every definition field with progress", %{context: context, user: user} do
    fields = %{
      "name" => "Read",
      "min_completions" => 2,
      "max_completions" => 4,
      "periodicity" => "day",
      "identity" => "Reader",
      "why_it_matters" => "Learn",
      "what_counts" => "One chapter"
    }

    assert {:ok, %{habit: habit, time_zone: "America/New_York"}} = Tools.execute("create_habit", context, fields)
    assert habit.current_completions == 0
    assert habit.why_it_matters == "Learn"
    assert habit.identity == "Reader"
    assert habit.what_counts == "One chapter"
    assert habit.periodicity == "day"
    assert habit.min_completions == 2
    assert habit.max_completions == 4
    assert Habits.get_habit!(user, habit.id).user_id == user.id
  end

  test "create keeps the domain's weekly default and uses UTC for an unset zone", %{context: context, user: user} do
    context = %{context | user: %{user | time_zone: nil}, scopes: [:write]}

    assert {:ok, %{habit: habit, time_zone: "Etc/UTC"}} =
             Tools.execute("create_habit", context, %{"name" => "Read", "min_completions" => 1})

    assert habit.periodicity == "week"
    assert habit.max_completions == nil
    assert habit.why_it_matters == nil
  end

  test "get uses local inclusive-start exclusive-end boundaries and uncapped progress", %{context: context, user: user} do
    habit = habit_fixture(%{user: user, periodicity: :day, min_completions: 1, why_it_matters: "Learn"})

    for time <- [~N[2026-10-04 03:59:59], ~N[2026-10-04 04:00:00], ~N[2026-10-05 03:59:59], ~N[2026-10-05 04:00:00]] do
      Repo.insert!(%Log{user_id: user.id, habit_id: habit.id, inserted_at: time, updated_at: time})
    end

    assert {:ok, %{habit: fetched, time_zone: "America/New_York"}} =
             Tools.execute("get_habit", context, %{"habit_id" => habit.id})

    assert fetched.current_completions == 2
    assert fetched.why_it_matters == "Learn"
    assert {:ok, %{habits: [^fetched]}} = Tools.execute("list_habits", context, %{})
  end

  test "update preserves omissions, clears explicit nulls, and counts the updated period", %{
    context: context,
    user: user
  } do
    habit =
      habit_fixture(%{
        user: user,
        periodicity: :day,
        min_completions: 1,
        max_completions: 3,
        identity: "Reader",
        why_it_matters: "Learn",
        what_counts: "One chapter"
      })

    time = ~N[2026-10-01 12:00:00]
    Repo.insert!(%Log{user_id: user.id, habit_id: habit.id, inserted_at: time, updated_at: time})

    arguments = %{"habit_id" => habit.id, "fields" => %{"periodicity" => "month", "max_completions" => nil}}
    assert {:ok, %{habit: updated}} = Tools.execute("update_habit", context, arguments)
    assert updated.name == habit.name
    assert updated.identity == "Reader"
    assert updated.min_completions == 1
    assert updated.max_completions == nil
    assert updated.current_completions == 1
    assert Habits.get_habit!(user, habit.id).periodicity == :month

    for field <- [:identity, :why_it_matters, :what_counts] do
      assert {:ok, %{habit: updated}} =
               Tools.execute("update_habit", context, %{
                 "habit_id" => habit.id,
                 "fields" => %{Atom.to_string(field) => nil}
               })

      assert Map.fetch!(updated, field) == nil
      assert user |> Habits.get_habit!(habit.id) |> Map.fetch!(field) == nil
    end
  end

  test "get and update conceal foreign and missing habits", %{context: context} do
    foreign = habit_fixture()

    for id <- [foreign.id, foreign.id + 1] do
      assert {:error, :not_found, "Habit not found."} = Tools.execute("get_habit", context, %{"habit_id" => id})

      assert {:error, :not_found, "Habit not found."} =
               Tools.execute("update_habit", context, %{"habit_id" => id, "fields" => %{"name" => "Changed"}})
    end

    assert Repo.get!(Habit, foreign.id).name == foreign.name
  end

  test "boundary validation rejects unknown fields and invalid types before writes", %{context: context, user: user} do
    valid = %{"name" => "Read", "min_completions" => 1}

    for invalid <- [
          %{},
          %{"name" => nil},
          %{"min_completions" => "1"},
          %{"min_completions" => 0},
          %{"min_completions" => 32},
          %{"periodicity" => "year"},
          %{"user_id" => user.id}
        ] do
      arguments =
        if invalid == %{} do
          %{}
        else
          Map.merge(valid, invalid)
        end

      assert {:error, :invalid_arguments, _} = Tools.execute("create_habit", context, arguments)
    end

    assert Repo.aggregate(Habit, :count) == 0
    habit = habit_fixture(%{user: user})

    for fields <- [%{"name" => nil}, %{"periodicity" => nil}, %{"user_id" => user.id}, %{"min_completions" => "1"}] do
      assert {:error, :invalid_arguments, _} =
               Tools.execute("update_habit", context, %{"habit_id" => habit.id, "fields" => fields})
    end

    for id <- [nil, "1", 0, -1, 1.5, 9_223_372_036_854_775_808] do
      assert {:error, :invalid_arguments, _} = Tools.execute("get_habit", context, %{"habit_id" => id})

      assert {:error, :invalid_arguments, _} =
               Tools.execute("update_habit", context, %{"habit_id" => id, "fields" => %{}})
    end
  end

  test "domain validation reports fields and rolls back invalid create and partial update", %{
    context: context,
    user: user
  } do
    assert {:error, :invalid_arguments, message} =
             Tools.execute("create_habit", context, %{"name" => "Read", "min_completions" => 3, "max_completions" => 2})

    assert message =~ "max_completions"
    assert Repo.aggregate(Habit, :count) == 0

    assert {:error, :invalid_arguments, message} =
             Tools.execute("create_habit", context, %{"name" => "   ", "min_completions" => 1})

    assert message =~ "name"
    habit = habit_fixture(%{user: user, min_completions: 1, max_completions: 3})

    assert {:error, :invalid_arguments, message} =
             Tools.execute("update_habit", context, %{"habit_id" => habit.id, "fields" => %{"min_completions" => 3}})

    assert message =~ "max_completions"
    assert Habits.get_habit!(user, habit.id).min_completions == 1
  end
end
