defmodule Mmentum.Logs do
  @moduledoc """
  Queries completion activity
  """

  import Ecto.Query, warn: false

  alias Mmentum.Accounts.User
  alias Mmentum.Habits.Habit
  alias Mmentum.Logs.Log
  alias Mmentum.Repo

  @type history_cursor :: %{id: pos_integer(), completed_at: DateTime.t()}

  @doc """
  Returns one page of completions, newest first, using IDs to break ties

  The cursor is the last entry from the previous page. A nil next_cursor means
  there are no more entries. Every query checks both habit and completion access
  """
  @spec list_history_page(User.t(), Habit.t(), pos_integer(), history_cursor() | nil) ::
          %{completions: [Log.t()], next_cursor: Log.t() | nil}
  def list_history_page(%User{} = user, %Habit{} = habit, page_size, cursor) do
    query =
      user
      |> for_habit_query(habit)
      |> exclude(:order_by)
      |> order_by([log], desc: log.inserted_at, desc: log.id)

    query =
      case cursor do
        nil ->
          query

        %{id: id, completed_at: completed_at} ->
          timestamp = completed_at |> DateTime.shift_zone!("Etc/UTC") |> DateTime.to_naive()

          where(query, [log], log.inserted_at < ^timestamp or (log.inserted_at == ^timestamp and log.id < ^id))
      end

    {completions, remaining} = query |> limit(^(page_size + 1)) |> Repo.all() |> Enum.split(page_size)

    next_cursor =
      case remaining do
        [] -> nil
        [_next] -> List.last(completions)
      end

    %{completions: completions, next_cursor: next_cursor}
  end

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
  Builds a scoped query for completion activity within inclusive-start, exclusive-end UTC boundaries
  """
  def in_range_query(%User{id: user_id}, start_of_range, end_of_range) do
    from(log in Log,
      where:
        log.user_id == ^user_id and log.inserted_at >= ^start_of_range and
          log.inserted_at < ^end_of_range,
      order_by: [asc: log.inserted_at, asc: log.id]
    )
  end
end
