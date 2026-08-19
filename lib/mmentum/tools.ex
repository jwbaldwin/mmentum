defmodule Mmentum.Tools do
  @moduledoc """
  Handles listing and invoking the tools available to Mmentum agents
  """

  alias Mmentum.Tools.Tool

  @tool_modules []

  def tool_modules, do: @tool_modules

  def definitions(tool_modules \\ tool_modules()) do
    Enum.map(tool_modules, &Tool.definition/1)
  end

  @doc "execute a tool by name"
  def execute(name, context, arguments) do
    execute(tool_modules(), name, context, arguments)
  end

  @doc "execute a tool from an explicit tool catalog"
  def execute(tool_modules, name, context, arguments) do
    case Enum.find(tool_modules, &(&1.name() == name)) do
      nil -> {:error, :tool_not_found}
      tool_module -> tool_module.execute(context, arguments)
    end
  end
end
