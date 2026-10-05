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

    belongs_to :user, Mmentum.Accounts.User
    has_many :logs, Mmentum.Logs.Log, on_delete: :delete_all

    timestamps()
  end

  @typedoc "Stored habit fields; associations may be unloaded until the owning query preloads them"
  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t() | nil,
          identity: String.t() | nil,
          why_it_matters: String.t() | nil,
          what_counts: String.t() | nil,
          periodicity: :day | :week | :month,
          min_completions: integer() | nil,
          max_completions: integer() | nil,
          user_id: integer() | nil,
          logs: [Mmentum.Logs.Log.t()] | Ecto.Association.NotLoaded.t()
        }

  @doc "Returns the most completions displayed for the habit's current period"
  def completion_cap(%__MODULE__{max_completions: nil, min_completions: minimum}), do: minimum
  def completion_cap(%__MODULE__{max_completions: maximum}), do: maximum

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
      :what_counts
    ])
    |> validate_required([:name, :min_completions, :periodicity])
    |> validate_number(:min_completions, greater_than: 0, less_than_or_equal_to: 31)
    |> validate_number(:max_completions, greater_than: 0, less_than_or_equal_to: 31)
    |> validate_completion_range()
    |> check_constraint(:max_completions,
      name: :habits_completion_range,
      message: "must be greater than the minimum"
    )
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
