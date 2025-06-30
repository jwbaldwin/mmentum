defmodule Mmentum.Habits.Habit do
  use Ecto.Schema
  import Ecto.Changeset

  schema "habits" do
    field :iterations, :integer
    field :periodicity, Ecto.Enum, values: [:day, :week, :month]
    field :name, :string

    field :momentum_score, :float, default: 0.0
    field :momentum_last_updated, :integer

    belongs_to :user, Mmentum.Accounts.User
    has_many :logs, Mmentum.Logs.Log, on_delete: :delete_all

    timestamps()
  end

  @doc false
  def changeset(habit, attrs) do
    habit
    |> cast(attrs, [
      :name,
      :iterations,
      :periodicity,
      :momentum_score,
      :momentum_last_updated
    ])
    |> validate_required([:name, :iterations, :periodicity])
    |> validate_number(:momentum_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
  end
end
