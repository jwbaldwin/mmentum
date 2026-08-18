defmodule Mmentum.Habits.Momentum do
  @moduledoc """
  Measures how strongly recent completions support a habit's chosen cadence

  Each completion is one vote for the identity behind the habit. Momentum is the
  share of expected votes recorded across the current period and the seven before
  it. A period contributes no more than the habit's minimum target, so steady
  practice matters more than bursts

  The score is `counted votes / (8 × minimum target) × 100`. The denominator always
  holds eight full targets, so a new habit earns trust one vote at a time

  The fixed eight-period window provides the decay: new periods move old votes out
  of the score without changing the permanent completion history

  This module sits outside the Handler, Service, Finder, and Value roles because it
  owns one shared domain calculation with no queries, side effects, or output shaping
  """

  alias Mmentum.Habits.Habit
  alias Mmentum.Time

  @period_count 8
  @utc_timezone "Etc/UTC"

  @doc "Returns the percentage of expected votes recorded across the last eight habit periods"
  def score(%Habit{} = habit, logs, %DateTime{} = current_time) do
    counted_votes =
      logs
      |> completion_counts(habit.periodicity, current_time)
      |> Map.values()
      |> Enum.sum_by(&min(&1, habit.min_completions))

    counted_votes / (@period_count * habit.min_completions) * 100
  end

  defp completion_counts(logs, periodicity, current_time) do
    recent_periods =
      0..(@period_count - 1)
      |> Enum.map(fn periods_ago ->
        current_time
        |> Time.shift_by_periods(periodicity, -periods_ago)
        |> Time.start_of_range(periodicity)
      end)
      |> MapSet.new()

    current_time_utc =
      current_time
      |> DateTime.shift_zone!(@utc_timezone)
      |> DateTime.to_naive()

    Enum.reduce(logs, %{}, fn log, counts ->
      period = completion_period(log.inserted_at, periodicity, current_time.time_zone)

      if NaiveDateTime.compare(log.inserted_at, current_time_utc) != :gt and
           MapSet.member?(recent_periods, period) do
        Map.update(counts, period, 1, &(&1 + 1))
      else
        counts
      end
    end)
  end

  defp completion_period(inserted_at, periodicity, time_zone) do
    inserted_at
    |> DateTime.from_naive!(@utc_timezone)
    |> DateTime.shift_zone!(time_zone)
    |> Time.start_of_range(periodicity)
  end
end
