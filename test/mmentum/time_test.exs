defmodule Mmentum.TimeTest do
  use ExUnit.Case, async: true

  alias Mmentum.Time

  describe "greeting_for_time_of_day/0" do
    test "4am returns an early greeting" do
      four_am = DateTime.new!(~D[2021-01-01], ~T[04:00:00.000], "America/New_York")

      assert Time.greeting_for_time_of_day(four_am) == "Good morning"
    end

    test "10am returns an early greeting" do
      ten_am = DateTime.new!(~D[2021-01-01], ~T[10:00:00.000], "America/New_York")

      assert Time.greeting_for_time_of_day(ten_am) == "Good morning"
    end

    test "11am returns an middle greeting" do
      eleven_am = DateTime.new!(~D[2021-01-01], ~T[11:00:00.000], "America/New_York")

      assert Time.greeting_for_time_of_day(eleven_am) == "Good afternoon"
    end

    test "5pm returns an middle greeting" do
      five_pm = DateTime.new!(~D[2021-01-01], ~T[17:00:00.000], "America/New_York")

      assert Time.greeting_for_time_of_day(five_pm) == "Good afternoon"
    end

    test "6pm returns an late greeting" do
      six_pm = DateTime.new!(~D[2021-01-01], ~T[18:00:00.000], "America/New_York")

      assert Time.greeting_for_time_of_day(six_pm) == "Good evening"
    end

    test "3am returns an late greeting" do
      three_am = DateTime.new!(~D[2021-01-01], ~T[03:00:00.000], "America/New_York")

      assert Time.greeting_for_time_of_day(three_am) == "Good evening"
    end
  end

  test "calendar offsets keep the intended day, week and month across DST" do
    spring = DateTime.new!(~D[2026-03-09], ~T[00:30:00], "America/Los_Angeles")
    fall = DateTime.new!(~D[2026-11-02], ~T[00:30:00], "America/Los_Angeles")
    april = DateTime.new!(~D[2026-04-01], ~T[00:30:00], "America/Los_Angeles")

    assert Time.start_of_range(spring, :day, -1) == ~N[2026-03-08 08:00:00]
    assert Time.start_of_range(spring, :week, -1) == ~N[2026-03-02 08:00:00]
    assert Time.start_of_range(fall, :day, -1) == ~N[2026-11-01 07:00:00]
    assert Time.start_of_range(fall, :week, -1) == ~N[2026-10-26 07:00:00]
    assert Time.start_of_range(april, :month, -1) == ~N[2026-03-01 08:00:00]
  end

  test "next starts follow local day, Monday and month boundaries" do
    time = DateTime.new!(~D[2026-05-31], ~T[23:30:00], "America/Los_Angeles")

    for period <- [:day, :week, :month] do
      assert Time.next_start_of_range(time, period) == ~N[2026-06-01 07:00:00]
    end
  end

  test "local days span 23 or 25 hours across DST" do
    for {date, hours} <- [{~D[2026-03-08], 23}, {~D[2026-11-01], 25}] do
      time = DateTime.new!(date, ~T[12:00:00], "America/Los_Angeles")
      assert NaiveDateTime.diff(Time.next_start_of_range(time, :day), Time.start_of_range(time, :day)) == hours * 3600
    end
  end

  test "a missing midnight starts at the first valid instant in Cairo" do
    time = DateTime.new!(~D[2026-04-24], ~T[12:00:00], "Africa/Cairo")

    assert Time.start_of_range(time, :day) == ~N[2026-04-23 22:00:00]
    assert Time.next_start_of_range(time, :day) == ~N[2026-04-24 21:00:00]
    assert Time.next_start_of_range(time, :day, -1) == Time.start_of_range(time, :day)
  end

  test "an overlapping midnight includes both occurrences in Havana" do
    time = DateTime.new!(~D[2026-11-01], ~T[12:00:00], "America/Havana")

    assert Time.start_of_range(time, :day) == ~N[2026-11-01 04:00:00]
    assert Time.next_start_of_range(time, :day) == ~N[2026-11-02 05:00:00]
    assert Time.next_start_of_range(time, :day, -1) == Time.start_of_range(time, :day)
  end
end
