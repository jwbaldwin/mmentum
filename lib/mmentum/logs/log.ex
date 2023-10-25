defmodule Mmentum.Logs.Log do
  use Ecto.Schema
  import Ecto.Changeset

  schema "logs" do
    belongs_to :user, Mmentum.Accounts.User
    belongs_to :habit, Mmentum.Habits.Habit

    timestamps()
  end

  @doc false
  def changeset(log, attrs) do
    log
    |> cast(attrs, [])
    |> validate_required([])
  end
end
