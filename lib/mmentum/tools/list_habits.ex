defmodule Mmentum.Tools.ListHabits do
  @moduledoc """
  Lists owned habits and their current-period completion counts

  Habits owns the query and calendar-period filtering; Values.Habit builds each
  public habit value. This tool owns argument validation and the response wrapper

  The result names the time zone used for every count. Users without a configured
  zone use `Etc/UTC`. Zoi generates the result type and JSON Schema from one definition
  """
  @behaviour Mmentum.Tools.Tool

  alias Mmentum.Habits
  alias Mmentum.Habits.Values.Habit
  alias Mmentum.Tools.Context
  alias Mmentum.Tools.Scope
  alias Mmentum.Tools.Tool

  @arguments_schema Zoi.map(%{}, unrecognized_keys: :error)
  @result_schema Zoi.map(
                   %{
                     time_zone:
                       Zoi.string(description: "IANA time zone used for period boundaries; Etc/UTC when unset"),
                     habits: Zoi.array(Habit.schema())
                   },
                   unrecognized_keys: :error
                 )

  @typedoc "Public habit fields and progress, with the time zone used to select the current periods"
  @type result :: unquote(Zoi.type_spec(@result_schema))

  @impl true
  @spec name() :: String.t()
  def name, do: "list_habits"

  @impl true
  @spec description() :: String.t()
  def description do
    "List your habits with current day, week, or month completion counts. Returns the time zone used; defaults to UTC when unset."
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
  def output_schema, do: Zoi.to_json_schema(@result_schema)

  @doc """
  Reads the caller's habits at `context.now`, using their time zone or UTC

  Accepts only an empty argument object. Returns an empty habit list for an empty
  account, or `:invalid_arguments` with a client-safe message for unexpected input
  The tool registry checks the required scope before calling this function
  """
  @impl true
  @spec execute(Context.t(), Tool.arguments()) :: {:ok, result()} | {:error, :invalid_arguments, String.t()}
  def execute(%{user: user, now: now}, arguments) do
    with {:ok, _arguments} <- Zoi.parse(@arguments_schema, arguments) do
      time_zone = user.time_zone || "Etc/UTC"
      current_time = DateTime.shift_zone!(now, time_zone)

      habits =
        user
        |> Habits.list_habits_with_current_progress(current_time)
        |> Habit.build()

      {:ok, %{time_zone: time_zone, habits: habits}}
    else
      {:error, _errors} -> {:error, :invalid_arguments, "This tool takes no arguments."}
    end
  end
end
