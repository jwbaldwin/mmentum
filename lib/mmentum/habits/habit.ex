defmodule Mmentum.Habits.Habit do
  use Ecto.Schema
  import Ecto.Changeset

  schema "habits" do
    field :iterations, :integer
    field :periodicity, Ecto.Enum, values: [:day, :week, :month]
    field :name, :string

    belongs_to :user, Mmentum.Accounts.User
    has_many :logs, Mmentum.Logs.Log, on_delete: :delete_all

    timestamps()
  end

  @doc false
  def changeset(habit, attrs) do
    habit
    |> cast(attrs, [:name, :iterations, :periodicity])
    |> validate_required([:name, :iterations, :periodicity])
  end
end
