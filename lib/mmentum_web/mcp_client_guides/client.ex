defmodule MmentumWeb.MCPClientGuides.Client do
  @moduledoc "Identifies a setup client and its publisher's light and dark logo assets"

  @type t :: %__MODULE__{key: String.t(), name: String.t(), logos: {String.t(), String.t()} | nil}

  @enforce_keys [:key, :name]
  defstruct [:key, :name, :logos]
end
