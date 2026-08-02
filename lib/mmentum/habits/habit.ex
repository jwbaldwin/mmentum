defmodule Mmentum.Habits.Habit do
  use Ecto.Schema
  import Ecto.Changeset

  schema "habits" do
    field :min_completions, :integer
    field :max_completions, :integer
    field :periodicity, Ecto.Enum, values: [:day, :week, :month], default: :week
    field :name, :string
    field :identity, :string
    field :why_it_matters, :string
    field :what_counts, :string

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
      :min_completions,
      :max_completions,
      :periodicity,
      :identity,
      :why_it_matters,
      :what_counts,
      :momentum_score,
      :momentum_last_updated
    ])
    |> validate_required([:name, :min_completions, :periodicity])
    |> validate_number(:min_completions, greater_than: 0, less_than_or_equal_to: 31)
    |> validate_number(:max_completions, greater_than: 0, less_than_or_equal_to: 31)
    |> validate_completion_range()
    |> validate_number(:momentum_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
  end

  defp validate_completion_range(changeset) do
    min_completions = get_field(changeset, :min_completions)
    max_completions = get_field(changeset, :max_completions)

    if max_completions <= min_completions do
      add_error(changeset, :max_completions, "must be greater than the minimum")
    else
      changeset
    end
  end
end
