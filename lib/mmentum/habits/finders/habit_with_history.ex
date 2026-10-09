defmodule Mmentum.Habits.Finders.HabitWithHistory do
  @moduledoc "Finds a user's habit with completions from its current and previous periods"

  import Ecto.Query

  alias Mmentum.Accounts.User
  alias Mmentum.Habits.Habit
  alias Mmentum.Logs
  alias Mmentum.Logs.Log
  alias Mmentum.Repo
  alias Mmentum.Time

  @type period :: %{
          starts_at: NaiveDateTime.t(),
          ends_before: NaiveDateTime.t(),
          completions: [Log.t()]
        }

  @doc "Returns both local calendar periods, including empty ones; another user's habit returns :not_found"
  @spec find(User.t(), integer(), DateTime.t()) ::
          {:ok, %{habit: Habit.t(), current_period: period(), previous_period: period()}} | {:error, :not_found}
  def find(%User{} = user, habit_id, %DateTime{} = current_time) do
    case Repo.get_by(Habit, id: habit_id, user_id: user.id) do
      nil ->
        {:error, :not_found}

      habit ->
        previous_start = Time.start_of_range(current_time, habit.periodicity, -1)
        current_start = Time.start_of_range(current_time, habit.periodicity)
        next_start = Time.next_start_of_range(current_time, habit.periodicity)

        completions =
          user
          |> Logs.for_habit_query(habit)
          |> where([log], log.inserted_at >= ^previous_start and log.inserted_at < ^next_start)
          |> exclude(:order_by)
          |> order_by([log], desc: log.inserted_at, desc: log.id)
          |> Repo.all()

        {current, previous} =
          Enum.split_with(completions, fn log -> NaiveDateTime.compare(log.inserted_at, current_start) != :lt end)

        {:ok,
         %{
           habit: %{habit | logs: current},
           current_period: %{starts_at: current_start, ends_before: next_start, completions: current},
           previous_period: %{starts_at: previous_start, ends_before: current_start, completions: previous}
         }}
    end
  end
end
