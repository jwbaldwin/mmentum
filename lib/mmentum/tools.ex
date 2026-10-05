defmodule Mmentum.Tools do
  @moduledoc """
  Handles listing and invoking the tools available to Mmentum agents
  """

  alias Mmentum.Tools.Tool

  @tool_modules []

  def tool_modules, do: @tool_modules

  def definitions do
    Enum.map(@tool_modules, &Tool.definition/1)
  end

  @doc "execute a tool by name"
  def execute(name, context, arguments) do
    case Enum.find(@tool_modules, &(&1.name() == name)) do
      nil ->
        {:error, :tool_not_found}

      tool_module ->
        if tool_module.required_scope() in context.scopes,
          do: tool_module.execute(context, arguments),
          else: {:error, :insufficient_scope, "This connection does not have permission to use this tool."}
    end
  end
end
