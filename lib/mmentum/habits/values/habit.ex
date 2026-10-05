defmodule Mmentum.Habits.Values.Habit do
  @moduledoc """
  Builds the public habit value from a habit with current-period logs loaded

  The Habits context owns loading and period filtering. This value selects fields
  and counts those logs without capping progress at the target. Its Zoi schema
  supplies both the output type and the schema used by tool response wrappers
  """

  alias Mmentum.Habits.Habit, as: HabitSchema

  @schema Zoi.map(
            %{
              id: Zoi.integer(description: "Habit identifier"),
              name: Zoi.string(),
              identity: Zoi.nullable(Zoi.string()),
              what_counts: Zoi.nullable(Zoi.string()),
              periodicity: Zoi.enum(["day", "week", "month"]),
              min_completions: Zoi.integer(description: "Required completions per period"),
              max_completions: Zoi.nullable(Zoi.integer(description: "Optional flexible target")),
              current_completions:
                Zoi.integer(gte: 0, description: "Actual completions in the current period, uncapped")
            },
            unrecognized_keys: :error
          )

  @typedoc "Public habit fields with an uncapped current-period completion count"
  @type t :: unquote(Zoi.type_spec(@schema))

  @spec schema() :: Zoi.schema()
  def schema, do: @schema

  @doc "Builds one habit value or an ordered list; requires current-period logs to be preloaded"
  @spec build(HabitSchema.t()) :: t()
  @spec build([HabitSchema.t()]) :: [t()]
  def build(habits) when is_list(habits) do
    Enum.map(habits, &build/1)
  end

  def build(%HabitSchema{} = habit) do
    %{
      id: habit.id,
      name: habit.name,
      identity: habit.identity,
      what_counts: habit.what_counts,
      periodicity: Atom.to_string(habit.periodicity),
      min_completions: habit.min_completions,
      max_completions: habit.max_completions,
      current_completions: length(habit.logs)
    }
  end
end
