defmodule Mmentum.Habits do
  @moduledoc """
  The Habits context
  """

  import Ecto.Query, warn: false
  alias Mmentum.Repo

  alias Mmentum.Accounts.User
  alias Mmentum.Habits.Habit
  alias Mmentum.Logs
  alias Mmentum.Logs.Log
  alias Mmentum.Time

  @doc "Lists the user's habits with completion activity from each habit's current period"
  def list_habits_with_current_progress(%User{id: user_id} = user, %DateTime{} = current_time) do
    periodicities = Ecto.Enum.values(Habit, :periodicity)
    starts = Enum.map(periodicities, &Time.start_of_range(current_time, &1))
    ends = Enum.map(periodicities, &Time.next_start_of_range(current_time, &1))
    broad_start = Enum.min(starts, NaiveDateTime)
    broad_end = Enum.max(ends, NaiveDateTime)

    Habit
    |> where(user_id: ^user_id)
    |> order_by([habit], asc: habit.inserted_at, asc: habit.id)
    |> preload(logs: ^Logs.in_range_query(user, broad_start, broad_end))
    |> Repo.all()
    |> Enum.map(fn habit ->
      start_of_period = Time.start_of_range(current_time, habit.periodicity)
      end_of_period = Time.next_start_of_range(current_time, habit.periodicity)

      current_logs =
        Enum.filter(habit.logs, fn log ->
          NaiveDateTime.compare(log.inserted_at, start_of_period) != :lt and
            NaiveDateTime.compare(log.inserted_at, end_of_period) == :lt
        end)

      %{habit | logs: current_logs}
    end)
  end

  @doc """
  Gets one of the user's habits or raises `Ecto.NoResultsError`
  """
  def get_habit!(%User{id: user_id}, id) do
    Repo.get_by!(Habit, id: id, user_id: user_id)
  end

  @doc "Gets one of the user's habits with completion activity from its current period"
  def get_habit_with_current_progress!(%User{} = user, id, %DateTime{} = current_time) do
    habit = get_habit!(user, id)
    start_of_range = Time.start_of_range(current_time, habit.periodicity)
    end_of_range = Time.next_start_of_range(current_time, habit.periodicity)

    Repo.preload(
      habit,
      [logs: Logs.in_range_query(user, start_of_range, end_of_range)],
      force: true
    )
  end

  @doc """
  Creates a habit for the user
  """
  def create_habit(%User{} = user, attrs \\ %{}) do
    Ecto.build_assoc(user, :habits)
    |> Habit.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates one of the user's habits
  """
  def update_habit(%User{} = user, id, attrs) do
    Repo.transact(fn repo ->
      with {:ok, habit} <- fetch_locked_habit(repo, user, id) do
        habit
        |> Habit.changeset(attrs)
        |> repo.update()
      end
    end)
  end

  @doc """
  Deletes one of the user's habits
  """
  def delete_habit(%User{} = user, id) do
    Repo.transact(fn repo ->
      with {:ok, habit} <- fetch_locked_habit(repo, user, id) do
        repo.delete(habit)
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking habit changes.

  ## Examples

      iex> change_habit(habit)
      %Ecto.Changeset{data: %Habit{}}

  """
  def change_habit(%Habit{} = habit, attrs \\ %{}) do
    Habit.changeset(habit, attrs)
  end

  @doc "Records a completion for one of the user's habits"
  def record_completion(%User{} = user, habit_id) do
    Repo.transact(fn repo ->
      with {:ok, habit} <- fetch_locked_habit(repo, user, habit_id) do
        insert_completion(repo, user, habit)
      end
    end)
  end

  @doc "Removes the latest completion in the habit's current local period, or returns :no_completion"
  def remove_current_period_completion(%User{} = user, habit_id) do
    Repo.transact(fn repo ->
      with {:ok, habit} <- fetch_locked_habit(repo, user, habit_id),
           {:ok, log} <- fetch_current_period_completion(repo, user, habit) do
        repo.delete(log)
      end
    end)
  end

  defp fetch_locked_habit(repo, %User{id: user_id}, id) do
    habit =
      repo.one(
        from habit in Habit,
          where: habit.id == ^id and habit.user_id == ^user_id,
          lock: "FOR UPDATE"
      )

    if habit, do: {:ok, habit}, else: {:error, :not_found}
  end

  defp insert_completion(repo, user, habit) do
    %Log{user_id: user.id, habit_id: habit.id}
    |> Log.completion_changeset()
    |> repo.insert()
  end

  defp fetch_current_period_completion(repo, user, habit) do
    current_time = Time.current_time(user.time_zone)
    start_of_period = Time.start_of_range(current_time, habit.periodicity)
    next_period = Time.next_start_of_range(current_time, habit.periodicity)

    log =
      user
      |> Logs.for_habit_query(habit)
      |> where([log], log.inserted_at >= ^start_of_period and log.inserted_at < ^next_period)
      |> exclude(:order_by)
      |> order_by([log], desc: log.inserted_at, desc: log.id)
      |> first()
      |> repo.one()

    if log, do: {:ok, log}, else: {:error, :no_completion}
  end
end
