defmodule Mmentum.Time do
  @moduledoc """
  A set of helpers for working with dates and providing human readable output.
  Operates in local time.
  """

  alias Timex.Format.DateTime.Formatters.Relative

  @greetings %{
    early: "Good morning",
    middle: "Good afternoon",
    late: "Good evening"
  }

  @weekstart :mon

  @human_format "%A at %l:%M%P"

  @doc """
  Returns the day of the week
  > current_day()
  >> Monday
  """
  @spec current_day() :: String.t()
  def current_day do
    Timex.local() |> Timex.weekday() |> Timex.day_name()
  end

  @doc """
  Returns the current time with timezone information
  """
  def current_time do
    Timex.local()
  end

  @doc """
  Returns the current timezone information
  >> "
  """
  def current_timezone do
    Timex.Timezone.local()
  end

  @doc """
  Returns a pre-written greeting for the time of day
  """
  def greeting_for_time_of_day do
    current_time()
    |> greeting_for_time_of_day()
  end

  def greeting_for_time_of_day(%DateTime{} = time) do
    hours_left = Timex.diff(Timex.end_of_day(time), time, :hours)

    cond do
      is_morning(hours_left) -> @greetings[:early]
      is_afternoon(hours_left) -> @greetings[:middle]
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
    hours_left = Timex.diff(Timex.end_of_day(time), time, :hours)

    cond do
      is_morning(hours_left) -> :morning
      is_afternoon(hours_left) -> :afternoon
      true -> :evening
    end
  end

  # Checks if hours left is between 4am (24 - 4 = 20) and 11am (24 - 11 = 13)
  defp is_morning(hours_left) do
    hours_left < 20 && hours_left >= 13
  end

  # Checks if hours left is between 11am (24 - 11 = 13) and 6pm (24 - 18 = 6)
  defp is_afternoon(hours_left) do
    hours_left < 13 && hours_left >= 6
  end

  def days_to_end(:week) do
    end_of_week =
      current_time()
      |> Timex.end_of_week(@weekstart)

    Timex.diff(end_of_week, current_time(), :days)
  end

  def days_to_end(:month) do
    end_of_month =
      current_time()
      |> Timex.end_of_month()

    Timex.diff(end_of_month, current_time(), :hours)
  end

  def days_to_end do
    IO.puts("This method needs an atom of either :week or :month")
  end

  @doc """
  Returns the date time for the start of some range in [:year, :month, :week, :day]
  """
  def start_of_range(range) do
    case range do
      :year ->
        Timex.beginning_of_year(Timex.now())

      :month ->
        Timex.beginning_of_month(Timex.now())

      :week ->
        Timex.beginning_of_week(Timex.now(), @weekstart)

      :day ->
        Timex.beginning_of_day(Timex.now())
    end
  end

  @doc """
  Returns the date time for the end of some range in [:year, :month, :week, :day]
  """
  def end_of_range(range) do
    case range do
      :year ->
        Timex.end_of_year(Timex.now())

      :month ->
        Timex.end_of_month(Timex.now())

      :week ->
        Timex.end_of_week(Timex.now(), @weekstart)

      :day ->
        Timex.end_of_day(Timex.now())
    end
  end

  @doc """
  Returns the string for a logged action in human-readable format
  >> Tuesday at 8:39pm
  Or returns relative time if under 90 minutes ago
  >> 13 minutes ago
  """
  def to_human_relative(logged_time) do
    time_difference = Timex.diff(logged_time, current_time(), :minutes)

    if time_difference > -90 do
      to_human_relative(logged_time, :relative)
    else
      to_human_relative(logged_time, :default)
    end
  end

  defp to_human_relative(logged_time, :default) do
    Timex.Timezone.convert(logged_time, current_timezone())
    |> Timex.format!(@human_format, :strftime)
  end

  defp to_human_relative(logged_time, :relative) do
    Timex.Timezone.convert(logged_time, current_timezone())
    |> Relative.format("{relative}")
    |> case do
      {:ok, time} -> time
      {:error, _} -> to_human_relative(logged_time, :default)
    end
  end
end
