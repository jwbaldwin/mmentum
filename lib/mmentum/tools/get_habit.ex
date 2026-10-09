defmodule Mmentum.Tools.GetHabit do
  @moduledoc "Returns a habit with current progress and recent completion history"
  @behaviour Mmentum.Tools.Tool

  alias Mmentum.Habits.Finders.HabitWithHistory
  alias Mmentum.Habits.Values.Habit, as: HabitValue
  alias Mmentum.Logs
  alias Mmentum.Logs.Values.Log, as: LogValue
  alias Mmentum.Tools.Context
  alias Mmentum.Tools.Scope
  alias Mmentum.Tools.Tool

  @cursor_input_schema Zoi.map(
                         %{
                           id: Tool.id_schema(),
                           completed_at: Zoi.ISO.to_datetime_struct(Zoi.ISO.datetime())
                         },
                         coerce: true,
                         unrecognized_keys: :error,
                         description: "Use the previous response's history.next_cursor unchanged to get the next page"
                       )
  @input_schema Zoi.map(
                  %{
                    "habit_id" => Tool.id_schema(),
                    "history" =>
                      Zoi.default(
                        Zoi.enum(["recent_periods", "all"],
                          description:
                            "Defaults to current and previous habit periods; all also returns a page of complete history"
                        ),
                        "recent_periods"
                      ),
                    "limit" =>
                      Zoi.optional(
                        Zoi.integer(
                          gte: 1,
                          lte: 100,
                          description: "Entries per history page, default 50; use only with history: all"
                        )
                      ),
                    "cursor" => Zoi.optional(@cursor_input_schema)
                  },
                  unrecognized_keys: :error
                )
  @period_schema Zoi.map(
                   %{
                     starts_at: Zoi.ISO.datetime(description: "Start of the period in UTC, included in its history"),
                     ends_before: Zoi.ISO.datetime(description: "Start of the next period in UTC, not included"),
                     completions: Zoi.array(LogValue.schema())
                   },
                   unrecognized_keys: :error
                 )
  @cursor_schema Zoi.map(
                   %{id: Tool.id_schema(), completed_at: Zoi.ISO.datetime()},
                   unrecognized_keys: :error
                 )
  @history_schema Zoi.map(
                    %{completions: Zoi.array(LogValue.schema()), next_cursor: Zoi.nullable(@cursor_schema)},
                    unrecognized_keys: :error
                  )
  @output_schema Zoi.map(
                   %{
                     time_zone: Zoi.string(),
                     habit: HabitValue.schema(),
                     current_period: @period_schema,
                     previous_period: @period_schema,
                     history: Zoi.nullable(@history_schema)
                   },
                   unrecognized_keys: :error
                 )
  @type output :: unquote(Zoi.type_spec(@output_schema))

  @impl true
  @spec name() :: String.t()
  def name, do: "get_habit"

  @impl true
  @spec description() :: String.t()
  def description do
    "Get a habit by habit_id with its definition, current progress, and completions from the current and previous habit periods. Daily habits return today and yesterday, weekly habits return this week and last week, and monthly habits return this month and last month. Use history: all to also browse complete history, newest first, with limit (default 50, maximum 100) and cursor. Pass history.next_cursor back as cursor until it is null. Period boundaries and completion times are in UTC; time_zone tells you which local calendar was used."
  end

  @impl true
  @spec required_scope() :: Scope.t()
  def required_scope, do: :read

  @impl true
  @spec annotations() :: map()
  def annotations, do: %{"readOnlyHint" => true, "openWorldHint" => false}

  @impl true
  @spec input_schema() :: map()
  def input_schema, do: Zoi.to_json_schema(@input_schema)

  @impl true
  @spec output_schema() :: map()
  def output_schema, do: Zoi.to_json_schema(@output_schema)

  @doc "Returns both recent periods, plus a page of complete history when requested"
  @impl true
  @spec execute(Context.t(), Tool.arguments()) ::
          {:ok, output()} | {:error, :not_found | :invalid_arguments, String.t()}
  def execute(%{user: user} = context, arguments) do
    with {:ok, %{"habit_id" => habit_id} = arguments} <- Tool.parse_arguments(@input_schema, arguments),
         :ok <- validate_history_options(arguments),
         current_time = Context.current_time(context),
         {:ok, %{habit: habit, current_period: current, previous_period: previous}} <-
           HabitWithHistory.find(user, habit_id, current_time) do
      {:ok,
       %{
         habit: HabitValue.build(habit),
         time_zone: current_time.time_zone,
         current_period: build_period(current),
         previous_period: build_period(previous),
         history: load_history(user, habit, arguments)
       }}
    else
      {:error, :not_found} -> {:error, :not_found, "Habit not found."}
      {:error, :invalid_arguments, _message} = error -> error
    end
  end

  defp validate_history_options(%{"history" => "all"}), do: :ok

  defp validate_history_options(arguments) do
    if Map.has_key?(arguments, "limit") or Map.has_key?(arguments, "cursor") do
      {:error, :invalid_arguments, "Use history: all when supplying limit or cursor."}
    else
      :ok
    end
  end

  defp load_history(_user, _habit, %{"history" => "recent_periods"}), do: nil

  defp load_history(user, habit, %{"history" => "all"} = arguments) do
    page = Logs.list_history_page(user, habit, Map.get(arguments, "limit", 50), Map.get(arguments, "cursor"))

    next_cursor =
      case page.next_cursor do
        nil -> nil
        completion -> completion |> LogValue.build() |> Map.take([:id, :completed_at])
      end

    %{completions: LogValue.build(page.completions), next_cursor: next_cursor}
  end

  defp build_period(period) do
    %{
      starts_at: period.starts_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_iso8601(),
      ends_before: period.ends_before |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_iso8601(),
      completions: LogValue.build(period.completions)
    }
  end
end
