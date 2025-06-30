defmodule Mmentum.Habits do
  @moduledoc """
  The Habits context.
  """

  import Ecto.Query, warn: false
  alias Mmentum.Repo

  alias Mmentum.Accounts.User
  alias Mmentum.Habits.Habit
  alias Mmentum.Habits.Momentum
  alias Mmentum.Logs
  alias Mmentum.Repo

  @allowed_ranges [:year, :month, :week, :day]

  @doc """
  Retrieve the user's list of habits
  """
  def list_habits(%User{id: user_id} = _user) do
    Habit
    |> where(user_id: ^user_id)
    |> preload(:logs)
    |> Repo.all()
  end

  @doc """
  Retrieve the user's list of habits with all logs in the specified range
  """
  def list_habits_with_range(%User{id: user_id} = _user, range \\ :week)
      when range in @allowed_ranges do
    Habit
    |> where(user_id: ^user_id)
    |> preload(logs: ^Logs.base_logs_range_query(range))
    |> Repo.all()
  end

  @doc """
  Gets a single habit.

  Raises `Ecto.NoResultsError` if the Habit does not exist.

  ## Examples

      iex> get_habit!(123)
      %Habit{}

      iex> get_habit!(456)
      ** (Ecto.NoResultsError)

  """
  def get_habit!(id), do: Repo.get!(Habit, id)

  @doc """
  Creates a habit.

  ## Examples

      iex> create_habit(%{field: value}, %User{})
      {:ok, %Habit{}}

      iex> create_habit(%{field: bad_value}, %User{})
      {:error, %Ecto.Changeset{}}

  """
  def create_habit(%User{} = user, attrs \\ %{}) do
    Ecto.build_assoc(user, :habits)
    |> Habit.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a habit.

  ## Examples

      iex> update_habit(habit, %{field: new_value})
      {:ok, %Habit{}}

      iex> update_habit(habit, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_habit(%Habit{} = habit, attrs) do
    habit
    |> Habit.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a habit.

  ## Examples

      iex> delete_habit(habit)
      {:ok, %Habit{}}

      iex> delete_habit(habit)
      {:error, %Ecto.Changeset{}}

  """
  def delete_habit(%Habit{} = habit) do
    Repo.delete(habit)
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

  # TODO: make this much less shitty
  @doc """
  Updates the momentum for a habit when a log is added.
  Applies exponential decay and then adds a boost with diminishing returns.
  """
  def update_momentum_on_log_added(%Habit{} = habit) do
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

    habit
    |> Habit.changeset(%{
      momentum_score: new_score,
      momentum_last_updated: new_timestamp
    })
    |> Repo.update()
  end

  # TODO: make this much less shitty
  @doc """
  Updates the momentum for a habit when a log is removed.
  Simply applies decay from last update to current time (no boost).
  """
  def update_momentum_on_log_removed(%Habit{} = habit) do
    current_time = Momentum.current_timestamp()
    half_life = Momentum.get_default_half_life(habit.periodicity)

    current_score =
      Momentum.calculate_current_score(
        habit.momentum_score || 0.0,
        habit.momentum_last_updated,
        current_time,
        half_life
      )

    habit
    |> Habit.changeset(%{
      momentum_score: current_score,
      momentum_last_updated: current_time
    })
    |> Repo.update()
  end

  @doc """
  Gets the current momentum score for a habit by applying decay from last update.
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

  @doc """
  Initializes momentum fields for a habit if they're not set.
  """
  def initialize_momentum(%Habit{} = habit) do
    habit
    |> Habit.changeset(%{
      momentum_score: 0.0
    })
    |> Repo.update()
  end
end
