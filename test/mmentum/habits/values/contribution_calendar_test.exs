defmodule Mmentum.Habits.Values.ContributionCalendarTest do
  use ExUnit.Case, async: true

  alias Mmentum.Habits.Values.ContributionCalendar

  test "groups UTC completion timestamps by the user's local date" do
    current_time = DateTime.from_naive!(~N[2026-08-16 12:00:00], "America/Los_Angeles")

    calendar =
      ContributionCalendar.build(
        [
          %{inserted_at: ~N[2026-08-16 06:30:00]},
          %{inserted_at: ~N[2026-08-16 08:00:00]}
        ],
        current_time
      )

    august_15 = Enum.find(calendar.days, &(&1.date == ~D[2026-08-15]))
    august_16 = Enum.find(calendar.days, &(&1.date == ~D[2026-08-16]))

    assert august_15.count == 1
    assert august_16.count == 1
    assert calendar.total_completions == 2
    assert calendar.active_days == 2
  end

  test "builds twelve calendar columns ending on the current local day" do
    current_time = DateTime.from_naive!(~N[2026-08-16 12:00:00], "Etc/UTC")

    calendar =
      ContributionCalendar.build(
        [
          %{inserted_at: ~N[2026-08-16 08:00:00]},
          %{inserted_at: ~N[2026-08-16 09:00:00]},
          %{inserted_at: ~N[2026-05-24 09:00:00]}
        ],
        current_time
      )

    assert calendar.week_count == 12
    assert length(calendar.days) == 84
    assert List.first(calendar.days).date == ~D[2026-05-25]
    assert List.last(calendar.days).date == ~D[2026-08-16]
    assert List.last(calendar.days).count == 2
    assert List.last(calendar.days).current?
    assert List.last(calendar.days).level == 2
    assert calendar.month_labels == [nil, "Jun", nil, nil, nil, nil, "Jul", nil, nil, nil, "Aug", nil]
    assert calendar.total_completions == 2
    assert calendar.summary =~ "2 completions across 1 day"
    assert calendar.aria_label =~ "2 completions across 1 day"
  end
end
