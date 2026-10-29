defmodule Mmentum.Tools.CreateHabit do
  @moduledoc "Creates a habit and returns its definition and current progress"
  @behaviour Mmentum.Tools.Tool

  alias Mmentum.Habits
  alias Mmentum.Habits.Values.Habit, as: HabitValue
  alias Mmentum.Tools.Context
  alias Mmentum.Tools.HabitFields
  alias Mmentum.Tools.Scope
  alias Mmentum.Tools.Tool

  @input_schema HabitFields.create_schema()
  @output_schema Zoi.map(
                   %{time_zone: Zoi.string(), habit: HabitValue.schema()},
                   unrecognized_keys: :error
                 )
  @type output :: unquote(Zoi.type_spec(@output_schema))

  @impl true
  @spec name() :: String.t()
  def name, do: "create_habit"

  @impl true
  @spec description() :: String.t()
  def description do
    "Create a habit with a name and min_completions (1–31). Periodicity is day, week, or month; defaults to week. Optional max_completions must exceed the minimum. Returns the habit with current progress and time zone. Retrying creates another habit."
  end

  @impl true
  @spec required_scope() :: Scope.t()
  def required_scope, do: :write

  @impl true
  @spec annotations() :: map()
  def annotations do
    %{"readOnlyHint" => false, "destructiveHint" => false, "idempotentHint" => false, "openWorldHint" => false}
  end

  @impl true
  @spec input_schema() :: map()
  def input_schema, do: Zoi.to_json_schema(@input_schema)

  @impl true
  @spec output_schema() :: map()
  def output_schema, do: Zoi.to_json_schema(@output_schema)

  @doc "Creates a habit for the caller; rejected fields return :invalid_arguments without writing"
  @impl true
  @spec execute(Context.t(), Tool.arguments()) :: {:ok, output()} | {:error, :invalid_arguments, String.t()}
  def execute(%{user: user} = context, arguments) do
    with {:ok, fields} <- Tool.parse_arguments(@input_schema, arguments),
         current_time = Context.current_time(context),
         {:ok, habit} <- Habits.create_habit(user, fields) do
      habit = Habits.load_current_progress(user, habit, current_time)
      {:ok, %{habit: HabitValue.build(habit), time_zone: current_time.time_zone}}
    else
      {:error, %Ecto.Changeset{} = changeset} -> Tool.validation_error(changeset)
      {:error, :invalid_arguments, _message} = error -> error
    end
  end
end
