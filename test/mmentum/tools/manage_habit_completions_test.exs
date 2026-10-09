defmodule Mmentum.Tools.ManageHabitCompletionsTest do
  use Mmentum.DataCase, async: true

  import Mmentum.AccountsFixtures
  import Mmentum.HabitsFixtures

  alias Mmentum.Logs.Log
  alias Mmentum.Repo
  alias Mmentum.Tools
  alias Mmentum.Tools.ManageHabitCompletions

  setup do
    user = user_fixture(%{time_zone: "America/New_York"})
    habit = habit_fixture(%{user: user, periodicity: :day})
    %{user: user, habit: habit, context: %{user: user, scopes: [:write], now: ~U[2026-10-09 02:00:00.123456Z]}}
  end

  test "adds offset timestamps and uses the captured now for every omitted time", %{
    context: context,
    user: user,
    habit: habit
  } do
    another = habit_fixture(%{user: user})

    assert {:ok, %{added: [dated, first_now, second_now], removed: []}} =
             execute(context, %{
               "add" => [
                 %{"habit_id" => habit.id, "completed_at" => "2026-10-08T23:59:59.987654-04:00"},
                 %{"habit_id" => another.id},
                 %{"habit_id" => habit.id}
               ]
             })

    assert dated.completed_at == "2026-10-09T03:59:59Z"
    assert dated.habit_id == habit.id
    assert first_now.completed_at == "2026-10-09T02:00:00Z"
    assert second_now.completed_at == first_now.completed_at
    assert first_now.habit_id == another.id
    assert Repo.get!(Log, dated.id).user_id == user.id

    context = %{context | scopes: [:read]}
    assert {:ok, %{habit: %{current_completions: 2}}} = Tools.execute("get_habit", context, %{"habit_id" => habit.id})
  end

  test "removes specific historical entries and returns them in request order", %{
    context: context,
    user: user,
    habit: habit
  } do
    first = insert_log(user, habit, ~N[2025-01-01 10:00:00])
    second = insert_log(user, habit, ~N[2025-01-02 10:00:00])
    untouched = insert_log(user, habit, ~N[2025-01-03 10:00:00])

    assert {:ok, %{added: [], removed: [removed_second, removed_first]}} =
             execute(context, %{"remove" => [second.id, first.id]})

    assert removed_second.id == second.id
    assert removed_first.id == first.id
    assert removed_first.completed_at == "2025-01-01T10:00:00Z"
    refute Repo.get(Log, first.id)
    refute Repo.get(Log, second.id)
    assert Repo.get!(Log, untouched.id)
  end

  test "replaces entries across habits in one batch", %{context: context, user: user, habit: habit} do
    another = habit_fixture(%{user: user})
    mistaken = insert_log(user, habit, ~N[2026-10-08 10:00:00])

    assert {:ok, %{added: [added], removed: [removed]}} =
             execute(context, %{"add" => [%{"habit_id" => another.id}], "remove" => [mistaken.id]})

    assert added.habit_id == another.id
    assert removed.id == mistaken.id
    refute Repo.get(Log, mistaken.id)
    assert Repo.get!(Log, added.id)
  end

  test "missing or foreign additions leave all removals and additions unchanged", %{
    context: context,
    user: user,
    habit: habit
  } do
    foreign = habit_fixture()
    existing = insert_log(user, habit, ~N[2026-10-08 10:00:00])

    for id <- [foreign.id, 9_223_372_036_854_775_807] do
      assert {:error, :not_found, _} =
               execute(context, %{
                 "add" => [%{"habit_id" => habit.id}, %{"habit_id" => id}],
                 "remove" => [existing.id]
               })

      assert Repo.all(Log) == [existing]
    end
  end

  test "missing or foreign removals leave the batch unchanged", %{context: context, user: user, habit: habit} do
    foreign_habit = habit_fixture()
    foreign = insert_log(%{user | id: foreign_habit.user_id}, foreign_habit, ~N[2026-10-08 10:00:00])
    existing = insert_log(user, habit, ~N[2026-10-08 10:00:00])

    for id <- [foreign.id, 9_223_372_036_854_775_807] do
      assert {:error, :not_found, _} =
               execute(context, %{"add" => [%{"habit_id" => habit.id}], "remove" => [existing.id, id]})

      assert Repo.get!(Log, existing.id)
      assert Repo.get!(Log, foreign.id)
      assert Repo.aggregate(Log, :count) == 2
    end
  end

  test "a matching log user_id cannot authorize removal from another user's habit", %{context: context, user: user} do
    foreign_habit = habit_fixture()
    inconsistent = insert_log(user, foreign_habit, ~N[2026-10-08 10:00:00])
    assert {:error, :not_found, _} = execute(context, %{"remove" => [inconsistent.id]})
    assert Repo.get!(Log, inconsistent.id)
  end

  test "rejects empty operations, duplicates, unknown fields and invalid IDs before writing", %{
    context: context,
    habit: habit
  } do
    for arguments <- [
          %{},
          %{"add" => []},
          %{"remove" => []},
          %{"add" => [%{"habit_id" => habit.id}], "remove" => []},
          %{"remove" => [1, 1]},
          %{"remove" => [0]},
          %{"remove" => [9_223_372_036_854_775_808]},
          %{"add" => [%{"habit_id" => "1"}]},
          %{"add" => [%{"habit_id" => 9_223_372_036_854_775_808}]},
          %{"add" => [%{"habit_id" => habit.id, "user_id" => 1}]},
          %{"add" => [%{"habit_id" => habit.id}], "user_id" => 1}
        ] do
      assert {:error, :invalid_arguments, _} = execute(context, arguments)
    end

    assert Repo.aggregate(Log, :count) == 0
  end

  test "rejects invalid timestamps rather than replacing them with now", %{context: context, habit: habit} do
    for time <- [nil, 1_760_000_000, "bad", "2026-02-30T12:00:00Z", "2026-10-08", "2026-10-08T12:00:00"] do
      assert {:error, :invalid_arguments, _} =
               execute(context, %{"add" => [%{"habit_id" => habit.id, "completed_at" => time}]})
    end

    assert Repo.aggregate(Log, :count) == 0
  end

  test "requires write permission before parsing or accessing user state" do
    assert {:error, :insufficient_scope, _} = Tools.execute("manage_habit_completions", %{scopes: [:read]}, %{})
  end

  test "repeated additions are distinct and repeated removals fail", %{context: context, habit: habit} do
    arguments = %{"add" => [%{"habit_id" => habit.id}]}
    assert {:ok, %{added: [first]}} = execute(context, arguments)
    assert {:ok, %{added: [second]}} = execute(context, arguments)
    refute first.id == second.id
    assert {:ok, _} = execute(context, %{"remove" => [first.id]})
    assert {:error, :not_found, _} = execute(context, %{"remove" => [first.id]})
    assert Repo.get!(Log, second.id)
  end

  test "publishes the agreed nonempty operations, unique removals and date-time format" do
    schema = ManageHabitCompletions.input_schema() |> Jason.encode!() |> Jason.decode!()
    assert schema["anyOf"] == [%{"required" => ["add"]}, %{"required" => ["remove"]}]
    assert schema["additionalProperties"] == false
    assert schema["properties"]["remove"]["uniqueItems"]
    assert schema["properties"]["add"]["minItems"] == 1
    assert schema["properties"]["add"]["items"]["properties"]["completed_at"]["format"] == "date-time"
  end

  defp execute(context, arguments), do: Tools.execute("manage_habit_completions", context, arguments)

  defp insert_log(user, habit, time) do
    Repo.insert!(%Log{user_id: user.id, habit_id: habit.id, inserted_at: time, updated_at: time})
  end
end
