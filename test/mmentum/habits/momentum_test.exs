defmodule Mmentum.Habits.MomentumTest do
  use ExUnit.Case, async: true

  alias Mmentum.Habits.Habit
  alias Mmentum.Habits.Momentum

  test "starts at zero without identity votes" do
    habit = habit(:week, 3)

    assert Momentum.score(habit, [], ~U[2026-08-18 12:00:00Z]) == 0.0
  end

  test "each completion fills one expected vote in the eight-period window" do
    habit = habit(:week, 2)
    current_time = ~U[2026-08-18 12:00:00Z]

    assert Momentum.score(habit, [log(~N[2026-08-18 10:00:00])], current_time) == 6.25
  end

  test "a period contributes no more than its minimum target" do
    habit = habit(:week, 2)
    current_time = ~U[2026-08-18 12:00:00Z]

    logs = [
      log(~N[2026-08-17 10:00:00]),
      log(~N[2026-08-18 10:00:00]),
      log(~N[2026-08-18 11:00:00])
    ]

    assert Momentum.score(habit, logs, current_time) == 12.5
  end

  test "eight complete periods build a full score" do
    habit = habit(:day, 1)
    current_time = ~U[2026-08-18 12:00:00Z]

    logs =
      Enum.map(0..7, fn days_ago ->
        log(NaiveDateTime.add(~N[2026-08-18 10:00:00], -days_ago * 86_400))
      end)

    assert Momentum.score(habit, logs, current_time) == 100.0
  end

  test "old votes decay by leaving the eight-period window" do
    habit = habit(:day, 1)
    logs = [log(~N[2026-08-11 10:00:00])]

    assert Momentum.score(habit, logs, ~U[2026-08-18 12:00:00Z]) == 12.5
    assert Momentum.score(habit, logs, ~U[2026-08-19 12:00:00Z]) == 0.0
  end

  test "monthly habits use eight calendar months" do
    habit = habit(:month, 1)
    current_time = ~U[2026-08-18 12:00:00Z]

    logs = [
      log(~N[2026-01-15 10:00:00]),
      log(~N[2025-12-15 10:00:00])
    ]

    assert Momentum.score(habit, logs, current_time) == 12.5
  end

  test "daily periods follow the user's local date" do
    habit = habit(:day, 1)
    current_time = DateTime.from_naive!(~N[2026-08-18 00:30:00], "America/Los_Angeles")

    logs = [
      log(~N[2026-08-18 06:45:00]),
      log(~N[2026-08-18 07:15:00])
    ]

    assert Momentum.score(habit, logs, current_time) == 25.0
  end

  test "future completions do not count" do
    habit = habit(:day, 1)

    assert Momentum.score(habit, [log(~N[2026-08-18 13:00:00])], ~U[2026-08-18 12:00:00Z]) == 0.0
  end

  test "daily momentum includes March 8 immediately after the spring transition" do
    current_time = DateTime.new!(~D[2026-03-09], ~T[00:30:00], "America/Los_Angeles")

    assert Momentum.score(habit(:day, 1), [log(~N[2026-03-08 18:00:00])], current_time) == 12.5
    assert Momentum.score(habit(:day, 1), [log(~N[2026-03-01 18:00:00])], current_time) == 0.0
  end

  test "weekly and monthly windows do not skip periods near DST midnight" do
    monday = DateTime.new!(~D[2026-03-09], ~T[00:30:00], "America/Los_Angeles")
    april = DateTime.new!(~D[2026-04-01], ~T[00:30:00], "America/Los_Angeles")
    fall = DateTime.new!(~D[2026-11-02], ~T[00:30:00], "America/Los_Angeles")

    assert Momentum.score(habit(:week, 1), [log(~N[2026-03-02 18:00:00])], monday) == 12.5
    assert Momentum.score(habit(:month, 1), [log(~N[2026-03-15 18:00:00])], april) == 12.5
    assert Momentum.score(habit(:day, 1), [log(~N[2026-11-01 18:00:00])], fall) == 12.5
  end

  defp habit(periodicity, minimum) do
    %Habit{periodicity: periodicity, min_completions: minimum}
  end

  defp log(inserted_at), do: %{inserted_at: inserted_at}
end
