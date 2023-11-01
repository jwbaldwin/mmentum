defmodule Mmentum.Logs do
  @moduledoc """
  The Logs context.
  """

  import Ecto.Query, warn: false

  alias Mmentum.Accounts.User
  alias Mmentum.Habits.Habit
  alias Mmentum.Logs.Log
  alias Mmentum.Repo
  alias Mmentum.Time

  @doc """
  List the logs for a user
  """
  def list_logs_by_user(%User{} = user) do
    Log
    |> where(user_id: ^user.id)
    |> Repo.all()
  end

  @doc """
  List all logs for a habit
  """
  def list_logs_by_habit(%User{} = user, %Habit{} = habit) do
    Log
    |> where(habit_id: ^habit.id, user_id: ^user.id)
    |> Repo.all()
  end

  def base_logs_range_query(range) do
    start_of_range = Time.start_of_range(range)
    end_of_range = Time.end_of_range(range)

    from l in Log,
      where: l.inserted_at >= ^start_of_range and l.inserted_at <= ^end_of_range
  end

  @doc """
  Gets a single log.

  Raises `Ecto.NoResultsError` if the Log does not exist.

  ## Examples

      iex> get_log!(123)
      %Log{}

      iex> get_log!(456)
      ** (Ecto.NoResultsError)

  """
  def get_log!(id), do: Repo.get!(Log, id)

  @doc """
  Creates a log.

  ## Examples

      iex> create_log(%{field: value})
      {:ok, %Log{}}

      iex> create_log(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_log(attrs \\ %{}) do
    %Log{}
    |> Log.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a log.

  ## Examples

      iex> update_log(log, %{field: new_value})
      {:ok, %Log{}}

      iex> update_log(log, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_log(%Log{} = log, attrs) do
    log
    |> Log.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a log.

  ## Examples

      iex> delete_log(log)
      {:ok, %Log{}}

      iex> delete_log(log)
      {:error, %Ecto.Changeset{}}

  """
  def delete_log(%Log{} = log) do
    Repo.delete(log)
  end

  def delete_most_recent_log(habit_id) do
    habit_id
    |> get_most_recent_log()
    |> case do
      nil -> {:error, "No logs found for this habit"}
      log -> delete_log(log)
    end
  end

  defp get_most_recent_log(habit_id) do
    Repo.one(
      from(log in Log,
        where: log.habit_id == ^habit_id,
        order_by: [desc: log.inserted_at],
        limit: 1
      )
    )
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking log changes.

  ## Examples

      iex> change_log(log)
      %Ecto.Changeset{data: %Log{}}

  """
  def change_log(%Log{} = log, attrs \\ %{}) do
    Log.changeset(log, attrs)
  end
end
