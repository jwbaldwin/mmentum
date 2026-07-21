defmodule Mmentum.Logs do
  @moduledoc """
  Queries completion activity.
  """

  import Ecto.Query, warn: false

  alias Mmentum.Accounts.User
  alias Mmentum.Habits.Habit
  alias Mmentum.Logs.Log
  alias Mmentum.Repo

  @doc """
  Lists a user's completion activity for one of their habits
  """
  def list_logs_by_habit(%User{} = user, %Habit{} = habit) do
    user
    |> for_habit_query(habit)
    |> Repo.all()
  end

  @doc """
  Builds the scoped query used to read and recalculate a habit's activity
  """
  def for_habit_query(%User{id: user_id}, %Habit{id: habit_id}) do
    from(log in Log,
      join: habit in Habit,
      on: habit.id == log.habit_id,
      where: log.habit_id == ^habit_id and log.user_id == ^user_id and habit.user_id == ^user_id,
      order_by: [asc: log.inserted_at, asc: log.id]
    )
  end

  @doc """
  Builds a scoped query for completion activity within UTC boundaries
  """
  def in_range_query(%User{id: user_id}, start_of_range, end_of_range) do
    from(log in Log,
      where:
        log.user_id == ^user_id and log.inserted_at >= ^start_of_range and
          log.inserted_at <= ^end_of_range,
      order_by: [asc: log.inserted_at, asc: log.id]
    )
  end
end
