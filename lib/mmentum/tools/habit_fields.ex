defmodule Mmentum.Tools.HabitFields do
  @moduledoc "Defines writable habit fields at the tool boundary; Ecto owns habit business validation"

  @fields %{
    "name" => Zoi.string(),
    "min_completions" => Zoi.integer(gte: 1, lte: 31),
    "periodicity" => Zoi.enum(["day", "week", "month"]),
    "max_completions" => Zoi.nullable(Zoi.integer(gte: 1, lte: 31)),
    "identity" => Zoi.nullable(Zoi.string()),
    "why_it_matters" => Zoi.nullable(Zoi.string()),
    "what_counts" => Zoi.nullable(Zoi.string())
  }

  @doc "Requires name and minimum for creation; omitted periodicity uses the domain's weekly default"
  @spec create_schema() :: Zoi.schema()
  def create_schema do
    fields =
      Map.new(@fields, fn {name, schema} ->
        if name in ["name", "min_completions"] do
          {name, schema}
        else
          {name, Zoi.optional(schema)}
        end
      end)

    Zoi.map(fields, unrecognized_keys: :error)
  end

  @doc "Accepts only supplied fields; null clears nullable fields and omission preserves stored values"
  @spec update_schema() :: Zoi.schema()
  def update_schema do
    fields = Map.new(@fields, fn {name, schema} -> {name, Zoi.optional(schema)} end)
    Zoi.map(fields, unrecognized_keys: :error)
  end
end
