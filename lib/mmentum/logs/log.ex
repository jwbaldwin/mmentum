defmodule Mmentum.Logs.Log do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  schema "logs" do
    belongs_to :user, Mmentum.Accounts.User
    belongs_to :habit, Mmentum.Habits.Habit

    timestamps()
  end

  @type t :: %__MODULE__{
          id: integer() | nil,
          user_id: integer() | nil,
          habit_id: integer() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  @doc false
  def completion_changeset(log) do
    log
    |> change()
    |> validate_required([:user_id, :habit_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:habit_id)
  end
end
