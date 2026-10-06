Code.require_file("../../../lib/mmentum/checks/entity_value.exs", __DIR__)

defmodule Mmentum.Checks.EntityValueTest do
  use ExUnit.Case, async: true

  alias Credo.SourceFile
  alias Credo.Test.CheckRunner
  alias Mmentum.Checks.EntityValue

  @schema """
  defmodule Mmentum.Habits.Habit do
    use Ecto.Schema
    @type t :: %__MODULE__{}
  end
  """

  @value """
  defmodule Mmentum.Habits.Values.Habit do
    alias Mmentum.Habits.Habit, as: HabitSchema
    @fields Zoi.map(%{id: Zoi.integer()})
    @type t :: unquote(Zoi.type_spec(@fields))
    def schema(), do: @fields
    @spec build(HabitSchema.t()) :: t()
    @spec build([HabitSchema.t()]) :: [t()]
    def build(habits) when is_list(habits), do: Enum.map(habits, &build/1)
    def build(%HabitSchema{} = habit), do: %{id: habit.id}
  end
  """

  setup_all do
    {:ok, _} = Application.ensure_all_started(:credo)
    :ok
  end

  test "accepts the entity contract with a schema attribute of any name" do
    assert issues(@value) == []
  end

  test "accepts a single builder without requiring a collection API" do
    value =
      @value
      |> String.replace("  @spec build([HabitSchema.t()]) :: [t()]\n", "")
      |> String.replace("  def build(habits) when is_list(habits), do: Enum.map(habits, &build/1)\n", "")

    assert issues(value) == []
  end

  test "checks the actual entity Value and leaves the presentation Value contract alone" do
    sources =
      Enum.map(
        [
          "lib/mmentum/habits/habit.ex",
          "lib/mmentum/habits/values/habit.ex",
          "lib/mmentum/habits/values/momentum_series.ex"
        ],
        &SourceFile.parse(File.read!(&1), &1)
      )

    assert CheckRunner.run_check(sources, EntityValue) == []
  end

  test "ignores test modules sharing the Values namespace" do
    source = SourceFile.parse("defmodule Mmentum.Habits.Values.HabitTest do end", "test/habit_test.exs")
    assert CheckRunner.run_check([source], EntityValue) == []
  end

  test "rejects a handwritten type instead of one generated from Zoi" do
    value = String.replace(@value, "unquote(Zoi.type_spec(@fields))", "map()")
    assert Enum.any?(issues(value), &String.contains?(&1.message, "Generate the Value's t()"))
  end

  test "rejects exposing a different schema than the generated type uses" do
    value = String.replace(@value, "def schema(), do: @fields", "def schema(), do: @other")
    assert [%{message: message}] = issues(value)
    assert message == "Define the Zoi schema in this Value and return it from schema/0"
  end

  test "rejects a schema owned by another module" do
    value = String.replace(@value, "Zoi.map(%{id: Zoi.integer()})", "Other.schema()")
    assert [%{message: message}] = issues(value)
    assert message == "Define the Zoi schema in this Value and return it from schema/0"
  end

  test "requires a public builder" do
    value = String.replace(@value, "def build", "defp build")
    assert [%{message: "Expose a public build/1 for this entity Value"}] = issues(value)
  end

  test "rejects an unrelated record type in the singular builder spec" do
    value = String.replace(@value, "build(HabitSchema.t())", "build(Other.t())")
    assert [%{message: message}] = issues(value)
    assert message == "Spec build/1 from Mmentum.Habits.Habit.t() to the Value's t()"
  end

  test "requires a list spec when a list clause exists" do
    value = String.replace(@value, "  @spec build([HabitSchema.t()]) :: [t()]\n", "")
    assert [%{message: "Spec the list builder from [Mmentum.Habits.Habit.t()] to [t()]"}] = issues(value)
  end

  test "requires a stored record type on the matching Ecto schema" do
    schema = String.replace(@schema, "  @type t :: %__MODULE__{}\n", "")
    assert [%{message: "Define the stored record's t() on Mmentum.Habits.Habit"}] = issues(@value, schema)
  end

  defp issues(value, schema \\ @schema, path \\ "lib/mmentum/habits/values/habit.ex") do
    CheckRunner.run_check(
      [SourceFile.parse(schema, "lib/mmentum/habits/habit.ex"), SourceFile.parse(value, path)],
      EntityValue
    )
  end
end
