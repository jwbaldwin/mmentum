defmodule Mmentum.Tools.ManageHabitCompletions do
  @moduledoc "Lets agents add habit completions and remove mistakes in the same call"
  @behaviour Mmentum.Tools.Tool

  alias Mmentum.Habits.Services.ManageHabitCompletions, as: ManageHabitCompletionsService
  alias Mmentum.Logs.Values.Log, as: LogValue
  alias Mmentum.Tools.Context
  alias Mmentum.Tools.Scope
  alias Mmentum.Tools.Tool

  @addition_schema Zoi.map(
                     %{
                       "habit_id" => Tool.id_schema(),
                       "completed_at" =>
                         [
                           description:
                             "Date and time with a UTC offset, such as 2026-10-08T18:30:00-04:00; defaults to now"
                         ]
                         |> Zoi.ISO.datetime()
                         |> Zoi.ISO.to_datetime_struct()
                         |> Zoi.optional()
                     },
                     unrecognized_keys: :error
                   )
  @input_schema Zoi.map(
                  %{
                    "add" => Zoi.optional(Zoi.array(@addition_schema, min_length: 1)),
                    "remove" => Zoi.optional(Zoi.array(Tool.id_schema(), min_length: 1, unique_items: true))
                  },
                  unrecognized_keys: :error
                )
  @output_schema Zoi.map(
                   %{added: Zoi.array(LogValue.schema()), removed: Zoi.array(LogValue.schema())},
                   unrecognized_keys: :error
                 )
  @type output :: unquote(Zoi.type_spec(@output_schema))

  @impl true
  @spec name() :: String.t()
  def name, do: "manage_habit_completions"

  @impl true
  @spec description() :: String.t()
  def description do
    "Add habit completions, remove entries by ID, or do both. All changes succeed together or none are saved. Each added entry counts as one completion. Supply completed_at with a date, time, and UTC offset, or omit it to use the current time. Returns added and removed entries in request order with UTC times."
  end

  @impl true
  @spec required_scope() :: Scope.t()
  def required_scope, do: :write

  @impl true
  @spec annotations() :: map()
  def annotations do
    %{"readOnlyHint" => false, "destructiveHint" => true, "idempotentHint" => false, "openWorldHint" => false}
  end

  @impl true
  @spec input_schema() :: map()
  def input_schema do
    @input_schema
    |> Zoi.to_json_schema()
    |> Map.put(:anyOf, [%{required: ["add"]}, %{required: ["remove"]}])
  end

  @impl true
  @spec output_schema() :: map()
  def output_schema, do: Zoi.to_json_schema(@output_schema)

  @doc "Returns added and removed completions"
  @impl true
  @spec execute(Context.t(), Tool.arguments()) ::
          {:ok, output()} | {:error, :not_found | :invalid_arguments, String.t()}
  def execute(%{user: user, now: now}, arguments) do
    with {:ok, changes} when map_size(changes) > 0 <- Tool.parse_arguments(@input_schema, arguments),
         additions =
           Enum.map(Map.get(changes, "add", []), fn %{"habit_id" => habit_id} = entry ->
             %{habit_id: habit_id, completed_at: Map.get(entry, "completed_at", now)}
           end),
         {:ok, %{added: added, removed: removed}} <-
           ManageHabitCompletionsService.call(user, additions, Map.get(changes, "remove", [])) do
      {:ok, %{added: LogValue.build(added), removed: LogValue.build(removed)}}
    else
      {:ok, %{}} -> {:error, :invalid_arguments, "Supply add, remove, or both."}
      {:error, :habit_not_found} -> {:error, :not_found, "Habit not found; no completions changed."}
      {:error, :completion_not_found} -> {:error, :not_found, "Completion not found; no completions changed."}
      {:error, :invalid_arguments, _message} = error -> error
    end
  end
end
