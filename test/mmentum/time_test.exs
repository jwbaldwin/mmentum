defmodule Mmentum.TimeTest do
  use ExUnit.Case, async: true

  alias Mmentum.Time

  describe "greeting_for_time_of_day/0" do
    test "4am returns an early greeting" do
      four_am = Timex.DateTime.new!(~D[2021-01-01], ~T[04:00:00.000], "America/New_York")

      assert Time.greeting_for_time_of_day(four_am) == "Good morning"
    end

    test "10am returns an early greeting" do
      ten_am = Timex.DateTime.new!(~D[2021-01-01], ~T[10:00:00.000], "America/New_York")

      assert Time.greeting_for_time_of_day(ten_am) == "Good morning"
    end

    test "11am returns an middle greeting" do
      eleven_am = Timex.DateTime.new!(~D[2021-01-01], ~T[11:00:00.000], "America/New_York")

      assert Time.greeting_for_time_of_day(eleven_am) == "Good afternoon"
    end

    test "5pm returns an middle greeting" do
      five_pm = Timex.DateTime.new!(~D[2021-01-01], ~T[17:00:00.000], "America/New_York")

      assert Time.greeting_for_time_of_day(five_pm) == "Good afternoon"
    end

    test "6pm returns an late greeting" do
      six_pm = Timex.DateTime.new!(~D[2021-01-01], ~T[18:00:00.000], "America/New_York")

      assert Time.greeting_for_time_of_day(six_pm) == "Good evening"
    end

    test "3am returns an late greeting" do
      three_am = Timex.DateTime.new!(~D[2021-01-01], ~T[03:00:00.000], "America/New_York")

      assert Time.greeting_for_time_of_day(three_am) == "Good evening"
    end
  end
end
