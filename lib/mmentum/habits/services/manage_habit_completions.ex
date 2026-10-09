defmodule Mmentum.Habits.Services.ManageHabitCompletions do
  @moduledoc "Adds and removes habit completions, this is an all or nothing operation"

  import Ecto.Query

  alias Mmentum.Accounts.User
  alias Mmentum.Habits.Habit
  alias Mmentum.Logs.Finders.CompletionsById
  alias Mmentum.Logs.Log
  alias Mmentum.Repo

  @type addition :: %{habit_id: integer(), completed_at: DateTime.t()}
  @type changes :: %{added: [Log.t()], removed: [Log.t()]}

  @doc @moduledoc
  @spec call(User.t(), [addition()], [integer()]) ::
          {:ok, changes()} | {:error, :habit_not_found | :completion_not_found}
  def call(%User{} = user, additions, removal_ids) do
    Repo.transact(fn ->
      with {:ok, removals} <- CompletionsById.list(user, removal_ids),
           habits_by_id = lock_habits(user, additions, removals),
           {:ok, removed} <- delete_completions(user, removal_ids),
           {:ok, added} <- insert_completions(user, habits_by_id, additions) do
        {:ok, %{added: added, removed: removed}}
      end
    end)
  end

  defp delete_completions(user, ids) do
    {_count, removed} =
      Repo.delete_all(
        from log in Log,
          where: log.id in ^ids and log.user_id == ^user.id,
          select: log
      )

    by_id = Map.new(removed, &{&1.id, &1})

    ids
    |> Enum.reduce_while({:ok, []}, fn id, {:ok, completions} ->
      case Map.fetch(by_id, id) do
        {:ok, completion} -> {:cont, {:ok, [completion | completions]}}
        :error -> {:halt, {:error, :completion_not_found}}
      end
    end)
    |> case do
      {:ok, completions} -> {:ok, Enum.reverse(completions)}
      {:error, :completion_not_found} = error -> error
    end
  end

  defp insert_completions(user, habits_by_id, additions) do
    additions
    |> Enum.reduce_while({:ok, []}, fn %{habit_id: habit_id, completed_at: completed_at}, {:ok, added} ->
      case Map.fetch(habits_by_id, habit_id) do
        {:ok, habit} ->
          timestamp =
            completed_at |> DateTime.shift_zone!("Etc/UTC") |> DateTime.to_naive() |> NaiveDateTime.truncate(:second)

          log =
            %Log{user_id: user.id, habit_id: habit.id, inserted_at: timestamp}
            |> Log.completion_changeset()
            |> Repo.insert!()

          {:cont, {:ok, [log | added]}}

        :error ->
          {:halt, {:error, :habit_not_found}}
      end
    end)
    |> case do
      {:ok, added} -> {:ok, Enum.reverse(added)}
      {:error, :habit_not_found} = error -> error
    end
  end

  defp lock_habits(user, additions, removals) do
    ids = Enum.uniq(Enum.map(additions, & &1.habit_id) ++ Enum.map(removals, & &1.habit_id))

    habits =
      Repo.all(
        from habit in Habit,
          where: habit.id in ^ids and habit.user_id == ^user.id,
          order_by: [asc: habit.id],
          lock: "FOR UPDATE"
      )

    Map.new(habits, &{&1.id, &1})
  end
end
