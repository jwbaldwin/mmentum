defmodule Mmentum.Time do
  @moduledoc """
  A set of helpers for working with dates and providing human readable output.
  Operates in local time.
  """

  @greetings %{
    early: "Good morning",
    middle: "Good afternoon",
    late: "Good evening"
  }

  @utc_timezone "Etc/UTC"

  @doc """
  Returns the day of the week
  > current_day()
  >> Monday
  """
  @spec current_day() :: String.t()
  def current_day do
    current_time()
    |> DateTime.to_date()
    |> Date.day_of_week()
    |> day_name()
  end

  @doc """
  Returns the current time with timezone information
  """
  def current_time do
    DateTime.now(current_timezone())
    |> case do
      {:ok, time} -> time
      {:error, _reason} -> DateTime.utc_now()
    end
  end

  @doc """
  Returns the current timezone information
  >> "
  """
  def current_timezone do
    System.get_env("TZ") || @utc_timezone
  end

  @doc """
  Returns a pre-written greeting for the time of day
  """
  def greeting_for_time_of_day do
    current_time()
    |> greeting_for_time_of_day()
  end

  def greeting_for_time_of_day(%DateTime{} = time) do
    cond do
      time.hour in 4..10 -> @greetings[:early]
      time.hour in 11..17 -> @greetings[:middle]
      true -> @greetings[:late]
    end
  end

  @doc """
  Returns :morning, :afternoon, :evening
  """
  def time_of_day do
    current_time()
    |> time_of_day()
  end

  def time_of_day(%DateTime{} = time) do
    cond do
      time.hour in 4..10 -> :morning
      time.hour in 11..17 -> :afternoon
      true -> :evening
    end
  end

  def days_to_end(:week) do
    current_date = DateTime.to_date(current_time())
    Date.diff(end_of_week(current_date), current_date)
  end

  def days_to_end(:month) do
    current_date = DateTime.to_date(current_time())
    Date.diff(Date.end_of_month(current_date), current_date)
  end

  def days_to_end do
    IO.puts("This method needs an atom of either :week or :month")
  end

  @doc """
  Returns the date time for the start of some range in [:year, :month, :week, :day]
  """
  def start_of_range(range) do
    current_time()
    |> beginning_of_range(range)
    |> to_utc_naive()
  end

  @doc """
  Returns the date time for the end of some range in [:year, :month, :week, :day]
  """
  def end_of_range(range) do
    current_time()
    |> end_of_range_for_time(range)
    |> to_utc_naive()
  end

  @doc """
  Returns the string for a logged action in human-readable format
  >> Tuesday at 8:39pm
  Or returns relative time if under 90 minutes ago
  >> 13 minutes ago
  """
  def to_human_relative(logged_time) do
    logged_time = DateTime.from_naive!(logged_time, @utc_timezone)
    time_difference = DateTime.diff(logged_time, DateTime.utc_now(), :minute)

    if time_difference > -90 do
      to_human_relative(logged_time, :relative)
    else
      to_human_relative(logged_time, :default)
    end
  end

  defp to_human_relative(logged_time, :default) do
    logged_time
    |> to_current_timezone()
    |> format_human_time()
  end

  defp to_human_relative(logged_time, :relative) do
    minutes_ago = max(DateTime.diff(DateTime.utc_now(), logged_time, :minute), 0)

    cond do
      minutes_ago == 0 -> "just now"
      minutes_ago == 1 -> "1 minute ago"
      minutes_ago < 60 -> "#{minutes_ago} minutes ago"
      true -> "1 hour ago"
    end
  end

  defp beginning_of_range(%DateTime{} = time, :year) do
    time.year
    |> Date.new!(1, 1)
    |> DateTime.new!(~T[00:00:00], time.time_zone)
  end

  defp beginning_of_range(%DateTime{} = time, :month) do
    time
    |> DateTime.to_date()
    |> Date.beginning_of_month()
    |> DateTime.new!(~T[00:00:00], time.time_zone)
  end

  defp beginning_of_range(%DateTime{} = time, :week) do
    time
    |> DateTime.to_date()
    |> beginning_of_week()
    |> DateTime.new!(~T[00:00:00], time.time_zone)
  end

  defp beginning_of_range(%DateTime{} = time, :day) do
    time
    |> DateTime.to_date()
    |> DateTime.new!(~T[00:00:00], time.time_zone)
  end

  defp end_of_range_for_time(%DateTime{} = time, :year) do
    time.year
    |> Date.new!(12, 31)
    |> DateTime.new!(~T[23:59:59.999999], time.time_zone)
  end

  defp end_of_range_for_time(%DateTime{} = time, :month) do
    time
    |> DateTime.to_date()
    |> Date.end_of_month()
    |> DateTime.new!(~T[23:59:59.999999], time.time_zone)
  end

  defp end_of_range_for_time(%DateTime{} = time, :week) do
    time
    |> DateTime.to_date()
    |> end_of_week()
    |> DateTime.new!(~T[23:59:59.999999], time.time_zone)
  end

  defp end_of_range_for_time(%DateTime{} = time, :day) do
    time
    |> DateTime.to_date()
    |> DateTime.new!(~T[23:59:59.999999], time.time_zone)
  end

  defp beginning_of_week(date), do: Date.add(date, 1 - Date.day_of_week(date))
  defp end_of_week(date), do: Date.add(beginning_of_week(date), 6)

  defp to_utc_naive(%DateTime{} = time) do
    time
    |> DateTime.shift_zone!(@utc_timezone)
    |> DateTime.to_naive()
  end

  defp to_current_timezone(%DateTime{} = time) do
    DateTime.shift_zone(time, current_timezone())
    |> case do
      {:ok, local_time} -> local_time
      {:error, _reason} -> time
    end
  end

  defp format_human_time(%DateTime{} = time) do
    hour =
      time.hour
      |> rem(12)
      |> case do
        0 -> 12
        hour -> hour
      end

    minute = time.minute |> Integer.to_string() |> String.pad_leading(2, "0")
    meridiem = if time.hour < 12, do: "am", else: "pm"

    "#{day_name(Date.day_of_week(DateTime.to_date(time)))} at #{hour}:#{minute}#{meridiem}"
  end

  defp day_name(1), do: "Monday"
  defp day_name(2), do: "Tuesday"
  defp day_name(3), do: "Wednesday"
  defp day_name(4), do: "Thursday"
  defp day_name(5), do: "Friday"
  defp day_name(6), do: "Saturday"
  defp day_name(7), do: "Sunday"
end
