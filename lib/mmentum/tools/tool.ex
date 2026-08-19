defmodule Mmentum.Tools.Tool do
  @moduledoc """
  Defines the contract shared by tools exposed to agents

  Mmentum agent and MCP clients will use the same tool definitions
  and executions.
  """

  @type context :: map()
  @type arguments :: map()
  @type result :: {:ok, map()} | {:error, term()}

  @callback name() :: String.t()
  @callback description() :: String.t()
  @callback input_schema() :: map()
  @callback output_schema() :: map()
  @callback annotations() :: map()
  @callback required_scope() :: String.t()
  @callback execute(context(), arguments()) :: result()

  @optional_callbacks annotations: 0

  @doc "Returns the MCP definition exposed for a tool module"
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
