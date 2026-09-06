defmodule Mmentum.Habits.Values.MomentumSeries do
  @moduledoc """
  Builds the current momentum score and its recent history from completion activity

  The series samples the end of each recent habit period and the current moment so
  the chart and displayed score always tell the same story
  """

  alias Mmentum.Habits.Habit
  alias Mmentum.Habits.Momentum
  alias Mmentum.Time

  @history_periods 8
  @utc_timezone "Etc/UTC"

  def build(%Habit{} = habit, logs, %DateTime{} = current_time) do
    {points, _previous_sample} =
      habit
      |> sample_times(current_time)
      |> Enum.map_reduce(nil, fn sample_time, previous_sample ->
        score = Momentum.score(habit, logs, sample_time)
        rounded_score = Float.round(score, 2)

        point = %{
          completion: completion_between?(logs, previous_sample, sample_time),
          timestamp: DateTime.to_unix(sample_time, :millisecond),
          score: rounded_score
        }

        {point, sample_time}
      end)

    current_score = points |> List.last() |> Map.fetch!(:score)

    %{
      aria_label: "Momentum history. Current score #{round(current_score)} out of 100",
      points: points,
      score: current_score
    }
  end

  defp completion_between?(_logs, nil, _sample_time), do: false

  defp completion_between?(logs, previous_sample, sample_time) do
    previous_sample = previous_sample |> DateTime.shift_zone!(@utc_timezone) |> DateTime.to_naive()
    sample_time = sample_time |> DateTime.shift_zone!(@utc_timezone) |> DateTime.to_naive()

    Enum.any?(logs, fn log ->
      NaiveDateTime.compare(log.inserted_at, previous_sample) == :gt &&
        NaiveDateTime.compare(log.inserted_at, sample_time) != :gt
    end)
  end

  defp sample_times(habit, current_time) do
    habit_started_at = DateTime.from_naive!(habit.inserted_at, @utc_timezone)

    completed_periods =
      (@history_periods - 1)..1//-1
      |> Enum.map(fn periods_ago ->
        current_time
        |> Time.next_start_of_range(habit.periodicity, -periods_ago)
        |> NaiveDateTime.add(-1, :microsecond)
        |> DateTime.from_naive!(@utc_timezone)
        |> DateTime.shift_zone!(current_time.time_zone)
      end)

    ([habit_started_at] ++ completed_periods ++ [current_time])
    |> Enum.filter(&(DateTime.compare(&1, habit_started_at) != :lt))
    |> Enum.uniq_by(&DateTime.to_unix(&1, :microsecond))
    |> Enum.sort(DateTime)
  end
end
