defmodule Mmentum.Tools.UpdateHabit do
  @moduledoc "Updates supplied habit fields through Habits and returns its Habit Value with current progress"
  @behaviour Mmentum.Tools.Tool

  alias Mmentum.Habits
  alias Mmentum.Habits.Values.Habit, as: HabitValue
  alias Mmentum.Tools.Context
  alias Mmentum.Tools.HabitFields
  alias Mmentum.Tools.Scope
  alias Mmentum.Tools.Tool

  @arguments_schema Zoi.map(
                      %{
                        "habit_id" => Zoi.integer(gte: 1, lte: 9_223_372_036_854_775_807),
                        "fields" => HabitFields.update_schema()
                      },
                      unrecognized_keys: :error
                    )
  @output_schema Zoi.map(
                   %{time_zone: Zoi.string(), habit: HabitValue.schema()},
                   unrecognized_keys: :error
                 )
  @type output :: unquote(Zoi.type_spec(@output_schema))

  @impl true
  @spec name() :: String.t()
  def name, do: "update_habit"

  @impl true
  @spec description() :: String.t()
  def description do
    "Update supplied fields on one of your habits by habit_id. Omitted fields stay unchanged; null clears identity, why_it_matters, what_counts, or max_completions. Targets are 1–31, and max_completions must exceed the minimum. Returns updated progress and time zone."
  end

  @impl true
  @spec required_scope() :: Scope.t()
  def required_scope, do: :write

  @impl true
  @spec annotations() :: map()
  def annotations do
    %{"readOnlyHint" => false, "destructiveHint" => true, "idempotentHint" => true, "openWorldHint" => false}
  end

  @impl true
  @spec input_schema() :: map()
  def input_schema, do: Zoi.to_json_schema(@arguments_schema)

  @impl true
  @spec output_schema() :: map()
  def output_schema, do: Zoi.to_json_schema(@output_schema)

  @doc "Updates an owned habit under its row lock; omitted fields are preserved and invalid changes do not write"
  @impl true
  @spec execute(Context.t(), Tool.arguments()) ::
          {:ok, output()} | {:error, :not_found | :invalid_arguments, String.t()}
  def execute(%{user: user} = context, arguments) do
    with {:ok, %{"habit_id" => habit_id, "fields" => fields}} <- Tool.parse_arguments(@arguments_schema, arguments),
         current_time = Context.current_time(context),
         {:ok, habit} <- Habits.update_habit(user, habit_id, fields) do
      habit = Habits.load_current_progress(user, habit, current_time)
      {:ok, %{habit: HabitValue.build(habit), time_zone: current_time.time_zone}}
    else
      {:error, :not_found} -> {:error, :not_found, "Habit not found."}
      {:error, %Ecto.Changeset{} = changeset} -> Tool.validation_error(changeset)
      {:error, :invalid_arguments, _message} = error -> error
    end
  end
end
