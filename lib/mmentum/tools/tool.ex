defmodule Mmentum.Tools.Tool do
  @moduledoc """
  Defines the contract shared by tools exposed to agents

  Mmentum agent and MCP clients will use the same tool definitions
  and executions.
  """

  alias Mmentum.Tools.Context
  alias Mmentum.Tools.Scope

  @type arguments :: map()
  @type result :: {:ok, map()} | {:error, atom(), String.t()}

  @callback name() :: String.t()
  @callback description() :: String.t()
  @callback input_schema() :: map()
  @callback output_schema() :: map()
  @callback annotations() :: map()
  @callback required_scope() :: Scope.t()
  @callback execute(Context.t(), arguments()) :: result()

  @optional_callbacks annotations: 0

  @doc "Validates tool arguments and returns field-specific, client-safe errors"
  @spec parse_arguments(Zoi.schema(), arguments()) :: {:ok, map()} | {:error, :invalid_arguments, String.t()}
  def parse_arguments(schema, arguments) do
    case Zoi.parse(schema, arguments) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, errors} -> {:error, :invalid_arguments, Zoi.prettify_errors(errors)}
    end
  end

  @doc "Turns rejected habit changes into field messages without exposing storage details"
  @spec validation_error(Ecto.Changeset.t()) :: {:error, :invalid_arguments, String.t()}
  def validation_error(%Ecto.Changeset{} = changeset) do
    messages =
      changeset
      |> Ecto.Changeset.traverse_errors(fn {message, options} ->
        Enum.reduce(options, message, fn {key, value}, message ->
          String.replace(message, "%{#{key}}", to_string(value))
        end)
      end)
      |> Enum.sort_by(fn {field, _messages} -> field end)
      |> Enum.flat_map(fn {field, messages} -> Enum.map(messages, &"#{field}: #{&1}") end)
      |> Enum.join("; ")

    {:error, :invalid_arguments, messages}
  end

  @doc "Returns the MCP definition exposed for a tool module"
  @spec definition(module()) :: map()
  def definition(tool_module) do
    definition = %{
      "name" => tool_module.name(),
      "description" => tool_module.description(),
      "inputSchema" => tool_module.input_schema(),
      "outputSchema" => tool_module.output_schema()
    }

    if function_exported?(tool_module, :annotations, 0) do
      Map.put(definition, "annotations", tool_module.annotations())
    else
      definition
    end
  end
end
