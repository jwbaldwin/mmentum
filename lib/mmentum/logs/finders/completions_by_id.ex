defmodule Mmentum.Logs.Finders.CompletionsById do
  @moduledoc "Finds a user's habit completions by ID"

  import Ecto.Query

  alias Mmentum.Accounts.User
  alias Mmentum.Habits.Habit
  alias Mmentum.Logs.Log
  alias Mmentum.Repo

  @doc """
  Returns completions in the requested order; IDs must not repeat

  Returns `:completion_not_found` if any entry is missing or belongs to another user
  """
  @spec list(User.t(), [integer()]) :: {:ok, [Log.t()]} | {:error, :completion_not_found}
  def list(%User{} = user, ids) do
    completions =
      Repo.all(
        from log in Log,
          join: habit in Habit,
          on: habit.id == log.habit_id,
          where: log.id in ^ids and log.user_id == ^user.id and habit.user_id == ^user.id
      )

    by_id = Map.new(completions, &{&1.id, &1})

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
end
