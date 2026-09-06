defmodule Mmentum.Habits.Values.MomentumSeriesTest do
  use ExUnit.Case, async: true

  alias Mmentum.Habits.Habit
  alias Mmentum.Habits.Momentum
  alias Mmentum.Habits.Values.MomentumSeries

  test "builds a flat zero series without completions" do
    habit = %Habit{
      min_completions: 3,
      periodicity: :week,
      inserted_at: ~N[2026-08-01 00:00:00]
    }

    current_time = ~U[2026-08-18 12:00:00Z]
    momentum = MomentumSeries.build(habit, [], current_time)

    assert length(momentum.points) > 1
    assert length(momentum.points) <= 9
    assert Enum.all?(momentum.points, &(&1.score == 0.0))
    assert List.last(momentum.points).timestamp == DateTime.to_unix(current_time, :millisecond)
    assert momentum.score == 0.0
    assert momentum.aria_label == "Momentum history. Current score 0 out of 100"
  end

  test "uses the same log-based score for the chart and current value" do
    habit = %Habit{
      min_completions: 2,
      periodicity: :week,
      inserted_at: ~N[2026-07-01 00:00:00]
    }

    current_time = ~U[2026-08-18 12:00:00Z]

    logs = [
      %{inserted_at: ~N[2026-08-10 10:00:00]},
      %{inserted_at: ~N[2026-08-11 10:00:00]},
      %{inserted_at: ~N[2026-08-18 10:00:00]}
    ]

    momentum = MomentumSeries.build(habit, logs, current_time)
    expected_score = Momentum.score(habit, logs, current_time)

    assert momentum.score == Float.round(expected_score, 2)
    assert List.last(momentum.points).score == momentum.score
    assert Enum.any?(momentum.points, &(&1.score > 0))
    assert Enum.any?(momentum.points, & &1.completion)
  end

  test "daily chart samples each local date once across the spring transition" do
    habit = %Habit{min_completions: 1, periodicity: :day, inserted_at: ~N[2026-03-01 00:00:00]}
    current_time = DateTime.new!(~D[2026-03-09], ~T[00:30:00], "America/Los_Angeles")
    momentum = MomentumSeries.build(habit, [%{inserted_at: ~N[2026-03-08 18:00:00]}], current_time)

    dates =
      momentum.points
      |> Enum.drop(1)
      |> Enum.map(fn point ->
        point.timestamp
        |> DateTime.from_unix!(:millisecond)
        |> DateTime.shift_zone!("America/Los_Angeles")
        |> DateTime.to_date()
      end)

    assert dates == Enum.map(2..9, &Date.new!(2026, 3, &1))
    assert momentum.score == 12.5
    assert Enum.at(momentum.points, -2).score == 12.5
  end
end
