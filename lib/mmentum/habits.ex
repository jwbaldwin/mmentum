defmodule Mmentum.Habits do
  @moduledoc """
  The Habits context
  """

  import Ecto.Query, warn: false
  alias Mmentum.Repo

  alias Mmentum.Accounts.User
  alias Mmentum.Habits.Habit
  alias Mmentum.Habits.Momentum
  alias Mmentum.Logs
  alias Mmentum.Logs.Log
  alias Mmentum.Time

  @allowed_ranges [:year, :month, :week, :day]

  @doc """
  Retrieve the user's list of habits with all logs in the specified range
  """
  def list_habits_with_range(%User{id: user_id} = user, %DateTime{} = current_time, range \\ :week)
      when range in @allowed_ranges do
    start_of_range = Time.start_of_range(current_time, range)
    end_of_range = Time.end_of_range(current_time, range)

    Habit
    |> where(user_id: ^user_id)
    |> order_by([habit], asc: habit.inserted_at, asc: habit.id)
    |> preload(logs: ^Logs.in_range_query(user, start_of_range, end_of_range))
    |> Repo.all()
  end

  @doc """
  Gets one of the user's habits or raises `Ecto.NoResultsError`
  """
  def get_habit!(%User{id: user_id}, id) do
    Repo.get_by!(Habit, id: id, user_id: user_id)
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
    with {:ok, habit} <- fetch_habit(user, id) do
      habit
      |> Habit.changeset(attrs)
      |> Repo.update()
    end
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

  @doc """
  Records a completion for one of the user's habits and updates its momentum
  """
  def record_completion(%User{} = user, habit_id) do
    Repo.transact(fn repo ->
      with {:ok, habit} <- fetch_locked_habit(repo, user, habit_id),
           {:ok, log} <- insert_completion(repo, user, habit),
           {:ok, _habit} <- repo.update(momentum_after_completion(habit)) do
        {:ok, log}
      end
    end)
  end

  @doc """
  Removes the user's most recent completion for a habit and recalculates its momentum
  """
  def remove_most_recent_completion(%User{} = user, habit_id) do
    Repo.transact(fn repo ->
      with {:ok, habit} <- fetch_locked_habit(repo, user, habit_id),
           {:ok, log} <- fetch_most_recent_completion(repo, user, habit),
           {:ok, log} <- repo.delete(log),
           logs = repo.all(Logs.for_habit_query(user, habit)),
           {:ok, _habit} <- repo.update(momentum_after_removal(habit, logs)) do
        {:ok, log}
      end
    end)
  end

  defp fetch_habit(%User{id: user_id}, id) do
    case Repo.get_by(Habit, id: id, user_id: user_id) do
      nil -> {:error, :not_found}
      habit -> {:ok, habit}
    end
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

  defp fetch_most_recent_completion(repo, user, habit) do
    log =
      user
      |> Logs.for_habit_query(habit)
      |> exclude(:order_by)
      |> order_by([log], desc: log.inserted_at, desc: log.id)
      |> first()
      |> repo.one()

    if log, do: {:ok, log}, else: {:error, :no_completion}
  end

  defp momentum_after_completion(habit) do
    current_time = Momentum.current_timestamp()
    half_life = Momentum.get_default_half_life(habit.periodicity)
    boost_amount = 60.0

    {new_score, new_timestamp} =
      Momentum.record_completion(
        habit.momentum_score || 0.0,
        habit.momentum_last_updated,
        current_time,
        half_life,
        boost_amount
      )

    Ecto.Changeset.change(habit, %{
      momentum_score: new_score,
      momentum_last_updated: new_timestamp
    })
  end

  defp momentum_after_removal(habit, logs) do
    current_time = Momentum.current_timestamp()
    half_life = Momentum.get_default_half_life(habit.periodicity)
    {new_score, new_timestamp} = recalculate_momentum_from_logs(logs, half_life, current_time)

    Ecto.Changeset.change(habit, %{
      momentum_score: new_score,
      momentum_last_updated: new_timestamp
    })
  end

  @doc """
  Gets the current momentum score for a habit by applying decay from last update
  """
  def get_current_momentum(%Habit{} = habit) do
    current_time = Momentum.current_timestamp()
    half_life = Momentum.get_default_half_life(habit.periodicity)

    Momentum.calculate_current_score(
      habit.momentum_score || 0.0,
      habit.momentum_last_updated,
      current_time,
      half_life
    )
  end

  # Recalculates momentum from scratch based on logs in chronological order.
  defp recalculate_momentum_from_logs([], _half_life, current_time) do
    {0.0, current_time}
  end

  defp recalculate_momentum_from_logs(logs, half_life, current_time) do
    boost_amount = 60.0

    logs
    |> Enum.reduce({0.0, nil}, fn log, {score, last_updated} ->
      log_time =
        log.inserted_at
        |> DateTime.from_naive!("Etc/UTC")
        |> DateTime.to_unix(:millisecond)

      Momentum.record_completion(
        score,
        last_updated,
        log_time,
        half_life,
        boost_amount
      )
    end)
    |> then(fn {final_score, last_log_time} ->
      # Apply decay from last log to current time
      current_score =
        Momentum.calculate_current_score(
          final_score,
          last_log_time,
          current_time,
          half_life
        )

      {current_score, current_time}
    end)
  end
end
