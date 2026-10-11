defmodule MmentumWeb.MCPClientGuides.Step do
  @moduledoc "One ordered setup instruction with optional copyable configuration or command"

  @type t :: %__MODULE__{
          title: String.t(),
          description: String.t(),
          code: String.t() | nil,
          label: String.t() | nil
        }

  @enforce_keys [:title, :description]
  defstruct [:title, :description, :code, :label]
end
