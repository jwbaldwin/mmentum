defmodule Mmentum.Logs.Values.Log do
  @moduledoc "Turns completion records into maps with IDs and UTC completion times"

  alias Mmentum.Logs.Log, as: LogSchema

  @schema Zoi.map(
            %{id: Zoi.integer(), habit_id: Zoi.integer(), completed_at: Zoi.ISO.datetime()},
            unrecognized_keys: :error
          )
  @type t :: unquote(Zoi.type_spec(@schema))

  @spec schema() :: Zoi.schema()
  def schema, do: @schema

  @doc "Builds one completion map or a list of maps, preserving list order"
  @spec build(LogSchema.t()) :: t()
  @spec build([LogSchema.t()]) :: [t()]
  def build(logs) when is_list(logs), do: Enum.map(logs, &build/1)

  def build(%LogSchema{} = log) do
    %{
      id: log.id,
      habit_id: log.habit_id,
      completed_at: log.inserted_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_iso8601()
    }
  end
end
