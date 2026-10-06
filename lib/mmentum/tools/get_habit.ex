defmodule Mmentum.Tools.GetHabit do
  @moduledoc "Gets one owned habit; Habits loads progress and the Habit Value selects public fields"
  @behaviour Mmentum.Tools.Tool

  alias Mmentum.Habits
  alias Mmentum.Habits.Values.Habit, as: HabitValue
  alias Mmentum.Tools.Context
  alias Mmentum.Tools.Scope
  alias Mmentum.Tools.Tool

  @arguments_schema Zoi.map(%{"habit_id" => Zoi.integer(gte: 1, lte: 9_223_372_036_854_775_807)},
                      unrecognized_keys: :error
                    )
  @output_schema Zoi.map(
                   %{time_zone: Zoi.string(), habit: HabitValue.schema()},
                   unrecognized_keys: :error
                 )
  @type output :: unquote(Zoi.type_spec(@output_schema))

  @impl true
  @spec name() :: String.t()
  def name, do: "get_habit"

  @impl true
  @spec description() :: String.t()
  def description do
    "Get one of your habits by habit_id, including its full definition and current-period completion count. Returns the time zone used; defaults to UTC when unset."
  end

  @impl true
  @spec required_scope() :: Scope.t()
  def required_scope, do: :read

  @impl true
  @spec annotations() :: map()
  def annotations, do: %{"readOnlyHint" => true, "openWorldHint" => false}

  @impl true
  @spec input_schema() :: map()
  def input_schema, do: Zoi.to_json_schema(@arguments_schema)

  @impl true
  @spec output_schema() :: map()
  def output_schema, do: Zoi.to_json_schema(@output_schema)

  @doc "Reads an owned habit at the invocation's local time; missing and unowned IDs both return :not_found"
  @impl true
  @spec execute(Context.t(), Tool.arguments()) ::
          {:ok, output()} | {:error, :not_found | :invalid_arguments, String.t()}
  def execute(%{user: user} = context, arguments) do
    with {:ok, %{"habit_id" => habit_id}} <- Tool.parse_arguments(@arguments_schema, arguments),
         current_time = Context.current_time(context),
         {:ok, habit} <- Habits.get_habit_with_current_progress(user, habit_id, current_time) do
      {:ok, %{habit: HabitValue.build(habit), time_zone: current_time.time_zone}}
    else
      {:error, :not_found} -> {:error, :not_found, "Habit not found."}
      {:error, :invalid_arguments, _message} = error -> error
    end
  end
end
