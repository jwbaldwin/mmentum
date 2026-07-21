defmodule Mmentum.Logs.Log do
  use Ecto.Schema
  import Ecto.Changeset

  schema "logs" do
    belongs_to :user, Mmentum.Accounts.User
    belongs_to :habit, Mmentum.Habits.Habit

    timestamps()
  end

  @doc false
  def completion_changeset(log) do
    log
    |> change()
    |> validate_required([:user_id, :habit_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:habit_id)
  end
end
