defmodule Mmentum.Tools.Scope do
  @moduledoc "Maps verified OAuth scope names to the permissions understood by tools"

  @type t :: :read | :write

  @doc "Keeps recognized tool permissions; unrelated OAuth scopes grant no tool access"
  @spec from_oauth([String.t()]) :: [t()]
  def from_oauth(scopes) do
    Enum.flat_map(scopes, fn
      "mmentum:read" -> [:read]
      "mmentum:write" -> [:write]
      _scope -> []
    end)
  end
end
