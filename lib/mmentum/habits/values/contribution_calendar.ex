defmodule Mmentum.Habits.Values.ContributionCalendar do
  @moduledoc "Builds a recent calendar of completion contributions in the user's local time"

  @weeks 12
  @utc_timezone "Etc/UTC"

  def build(logs, %DateTime{} = current_time) do
    end_date = DateTime.to_date(current_time)
    current_week_start = Date.add(end_date, 1 - Date.day_of_week(end_date))
    start_date = Date.add(current_week_start, -7 * (@weeks - 1))

    counts_by_date =
      logs
      |> Enum.map(&local_date(&1.inserted_at, current_time.time_zone))
      |> Enum.frequencies()

    days =
      start_date
      |> Date.range(end_date)
      |> Enum.map(fn date ->
        count = Map.get(counts_by_date, date, 0)

        %{
          count: count,
          current?: date == end_date,
          date: date,
          label: day_label(date, count),
          level: min(count, 3)
        }
      end)

    {month_labels, _month} =
      Enum.map_reduce(0..(@weeks - 1), nil, fn week, previous_month ->
        date = Date.add(start_date, week * 7)
        label = if date.month != previous_month, do: Calendar.strftime(date, "%b")
        {label, date.month}
      end)

    month_labels =
      if Enum.at(month_labels, 1), do: List.replace_at(month_labels, 0, nil), else: month_labels

    total_completions = Enum.sum_by(days, & &1.count)
    active_days = Enum.count(days, &(&1.count > 0))
    date_range = "#{short_date(start_date)}–#{short_date(end_date)}"

    %{
      active_days: active_days,
      aria_label: aggregate_label(total_completions, active_days, start_date, end_date),
      date_range: date_range,
      days: days,
      month_labels: month_labels,
      summary: summary(total_completions, active_days, date_range),
      total_completions: total_completions,
      week_count: @weeks
    }
  end

  defp local_date(%NaiveDateTime{} = inserted_at, time_zone) do
    inserted_at
    |> DateTime.from_naive!(@utc_timezone)
    |> DateTime.shift_zone!(time_zone)
    |> DateTime.to_date()
  end

  defp day_label(date, 0), do: "#{long_date(date)}: no contributions recorded"
  defp day_label(date, 1), do: "#{long_date(date)}: 1 completion"
  defp day_label(date, count), do: "#{long_date(date)}: #{count} completions"

  defp aggregate_label(0, _active_days, start_date, end_date) do
    "Recent contributions from #{long_date(start_date)} to #{long_date(end_date)}: none recorded"
  end

  defp aggregate_label(total, active_days, start_date, end_date) do
    "Recent contributions from #{long_date(start_date)} to #{long_date(end_date)}: " <>
      "#{completion_text(total)} across #{day_text(active_days)}"
  end

  defp summary(0, _active_days, date_range), do: "None so far · #{date_range}"

  defp summary(total, active_days, date_range) do
    "#{completion_text(total)} across #{day_text(active_days)} · #{date_range}"
  end

  defp completion_text(1), do: "1 completion"
  defp completion_text(count), do: "#{count} completions"
  defp day_text(1), do: "1 day"
  defp day_text(count), do: "#{count} days"

  defp short_date(date), do: Calendar.strftime(date, "%b %-d")
  defp long_date(date), do: Calendar.strftime(date, "%B %-d, %Y")
end
