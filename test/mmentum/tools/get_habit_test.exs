defmodule Mmentum.Tools.GetHabitTest do
  use Mmentum.DataCase, async: true

  import Mmentum.AccountsFixtures
  import Mmentum.HabitsFixtures

  alias Mmentum.Logs.Log
  alias Mmentum.Repo
  alias Mmentum.Tools

  for {periodicity, time_zone, now, previous_start, current_start, next_start} <- [
        {:day, "America/Los_Angeles", ~U[2026-11-02 08:30:00Z], ~N[2026-11-01 07:00:00], ~N[2026-11-02 08:00:00],
         ~N[2026-11-03 08:00:00]},
        {:week, "America/New_York", ~U[2026-10-05 02:00:00Z], ~N[2026-09-21 04:00:00], ~N[2026-09-28 04:00:00],
         ~N[2026-10-05 04:00:00]},
        {:month, nil, ~U[2024-03-01 00:30:00Z], ~N[2024-02-01 00:00:00], ~N[2024-03-01 00:00:00],
         ~N[2024-04-01 00:00:00]}
      ] do
    @periodicity periodicity
    @time_zone time_zone
    @now now
    @previous_start previous_start
    @current_start current_start
    @next_start next_start

    test "#{periodicity} habits return the current and previous local periods without older or next-period entries" do
      user = user_fixture(%{time_zone: @time_zone})
      habit = habit_fixture(%{user: user, periodicity: @periodicity, min_completions: 1})
      insert_log(user, habit, NaiveDateTime.add(@previous_start, -1))
      previous_first = insert_log(user, habit, @previous_start)
      previous_last = insert_log(user, habit, NaiveDateTime.add(@current_start, -1))
      current_first = insert_log(user, habit, @current_start)
      current_last = insert_log(user, habit, NaiveDateTime.add(@next_start, -1))
      insert_log(user, habit, @next_start)

      assert {:ok, result} = execute(user, @now, %{"habit_id" => habit.id})
      assert result.time_zone == (@time_zone || "Etc/UTC")
      assert result.habit.periodicity == Atom.to_string(@periodicity)
      assert result.habit.current_completions == 2

      assert result.current_period.starts_at == utc_string(@current_start)
      assert result.current_period.ends_before == utc_string(@next_start)
      assert Enum.map(result.current_period.completions, & &1.id) == [current_last.id, current_first.id]

      assert result.previous_period.starts_at == utc_string(@previous_start)
      assert result.previous_period.ends_before == result.current_period.starts_at
      assert Enum.map(result.previous_period.completions, & &1.id) == [previous_last.id, previous_first.id]
      assert result.history == nil

      assert {:ok, %{habits: [listed]}} = Tools.execute("list_habits", context(user, @now), %{})
      assert listed == result.habit
      refute Map.has_key?(listed, :current_period)
    end
  end

  test "an empty habit still returns both periods" do
    user = user_fixture()
    habit = habit_fixture(%{user: user, periodicity: :month})

    assert {:ok, result} = execute(user, ~U[2026-01-01 12:00:00Z], %{"habit_id" => habit.id})
    assert result.habit.current_completions == 0
    assert result.current_period.completions == []
    assert result.previous_period.completions == []
    assert result.previous_period.starts_at == "2025-12-01T00:00:00Z"
    assert result.previous_period.ends_before == "2026-01-01T00:00:00Z"
  end

  test "recent history excludes other habits and completions belonging to another user" do
    user = user_fixture()
    another_user = user_fixture()
    habit = habit_fixture(%{user: user, periodicity: :day})
    another_habit = habit_fixture(%{user: user})
    time = ~N[2026-10-09 10:00:00]
    expected = insert_log(user, habit, time)
    insert_log(user, another_habit, time)
    insert_log(another_user, habit, time)

    assert {:ok, result} = execute(user, ~U[2026-10-09 12:00:00Z], %{"habit_id" => habit.id})
    assert Enum.map(result.current_period.completions, & &1.id) == [expected.id]
    assert result.habit.current_completions == 1
  end

  test "all history pages through equal timestamps without changing the recent periods or progress" do
    user = user_fixture()
    habit = habit_fixture(%{user: user, periodicity: :day})
    oldest = insert_log(user, habit, ~N[2025-01-01 10:00:00])
    tied_first = insert_log(user, habit, ~N[2026-10-08 10:00:00])
    tied_second = insert_log(user, habit, ~N[2026-10-08 10:00:00])
    newest = insert_log(user, habit, ~N[2026-10-09 10:00:00])
    insert_log(user, habit_fixture(%{user: user}), ~N[2026-10-08 10:00:00])
    insert_log(user_fixture(), habit, ~N[2026-10-08 10:00:00])
    now = ~U[2026-10-09 12:00:00Z]
    arguments = %{"habit_id" => habit.id, "history" => "all", "limit" => 2}

    assert {:ok, first} = execute(user, now, arguments)
    assert Enum.map(first.history.completions, & &1.id) == [newest.id, tied_second.id]
    assert first.history.next_cursor == %{completed_at: "2026-10-08T10:00:00Z", id: tied_second.id}
    assert first.habit.current_completions == 1

    cursor =
      first.history.next_cursor
      |> Jason.encode!()
      |> Jason.decode!()
      |> Map.put("completed_at", "2026-10-08T06:00:00-04:00")

    assert {:ok, second} = execute(user, now, Map.put(arguments, "cursor", cursor))
    assert Enum.map(second.history.completions, & &1.id) == [tied_first.id, oldest.id]
    assert second.history.next_cursor == nil
    assert second.habit == first.habit
    assert second.current_period == first.current_period
    assert second.previous_period == first.previous_period
  end

  test "a cursor still works after its completion is removed and newer entries are added" do
    user = user_fixture()
    habit = habit_fixture(%{user: user})
    oldest = insert_log(user, habit, ~N[2025-01-01 10:00:00])
    middle = insert_log(user, habit, ~N[2025-01-02 10:00:00])
    newest = insert_log(user, habit, ~N[2025-01-03 10:00:00])
    now = ~U[2026-10-09 12:00:00Z]
    arguments = %{"habit_id" => habit.id, "history" => "all", "limit" => 1}

    assert {:ok, first} = execute(user, now, arguments)
    assert Enum.map(first.history.completions, & &1.id) == [newest.id]
    Repo.delete!(newest)
    insert_log(user, habit, ~N[2026-10-09 10:00:00])

    cursor = first.history.next_cursor |> Jason.encode!() |> Jason.decode!()
    assert {:ok, second} = execute(user, now, Map.put(arguments, "cursor", cursor))
    assert Enum.map(second.history.completions, & &1.id) == [middle.id]
    cursor = second.history.next_cursor |> Jason.encode!() |> Jason.decode!()
    assert {:ok, last} = execute(user, now, Map.put(arguments, "cursor", cursor))
    assert Enum.map(last.history.completions, & &1.id) == [oldest.id]
    assert last.history.next_cursor == nil
  end

  test "all history defaults to fifty entries and allows up to one hundred" do
    user = user_fixture()
    habit = habit_fixture(%{user: user})
    now = ~U[2026-10-09 12:00:00Z]
    arguments = %{"habit_id" => habit.id, "history" => "all"}

    assert {:ok, empty} = execute(user, now, arguments)
    assert empty.history == %{completions: [], next_cursor: nil}

    completions = for _ <- 1..51, do: insert_log(user, habit, ~N[2025-01-01 10:00:00])
    assert {:ok, first} = execute(user, now, arguments)

    assert Enum.map(first.history.completions, & &1.id) ==
             completions |> Enum.reverse() |> Enum.take(50) |> Enum.map(& &1.id)

    assert first.history.next_cursor

    assert {:ok, all} = execute(user, now, Map.put(arguments, "limit", 100))
    assert length(all.history.completions) == 51
    assert all.history.next_cursor == nil
  end

  test "rejects invalid history options and paging without all history" do
    user = user_fixture()
    habit = habit_fixture(%{user: user})
    arguments = %{"habit_id" => habit.id, "history" => "all"}
    cursor = %{"completed_at" => "2026-10-08T10:00:00Z", "id" => 1}

    for options <- [
          %{"history" => true},
          %{"history" => "current_period"},
          %{"limit" => 0},
          %{"limit" => 101},
          %{"limit" => "10"},
          %{"cursor" => "bad"},
          %{"cursor" => nil},
          %{"cursor" => Map.put(cursor, "id", 0)},
          %{"cursor" => Map.put(cursor, "id", 9_223_372_036_854_775_808)},
          %{"cursor" => Map.put(cursor, "completed_at", "2026-10-08T10:00:00")},
          %{"cursor" => Map.put(cursor, "habit_id", habit.id)},
          %{"history" => "recent_periods", "limit" => 1},
          %{"history" => "recent_periods", "cursor" => cursor}
        ] do
      assert {:error, :invalid_arguments, _} = execute(user, ~U[2026-10-09 12:00:00Z], Map.merge(arguments, options))
    end

    assert {:error, :invalid_arguments, _} =
             execute(user, ~U[2026-10-09 12:00:00Z], %{"habit_id" => habit.id, "limit" => 1})
  end

  test "all history does not expose another user's habit" do
    user = user_fixture()
    foreign = habit_fixture()

    assert {:error, :not_found, "Habit not found."} =
             execute(user, ~U[2026-10-09 12:00:00Z], %{"habit_id" => foreign.id, "history" => "all"})
  end

  defp execute(user, now, arguments), do: Tools.execute("get_habit", context(user, now), arguments)

  defp context(user, now), do: %{user: user, scopes: [:read], now: now}

  defp insert_log(user, habit, time) do
    Repo.insert!(%Log{user_id: user.id, habit_id: habit.id, inserted_at: time, updated_at: time})
  end

  defp utc_string(time), do: time |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_iso8601()
end
