defmodule MmentumWeb.MCPClientGuides.Guide do
  @moduledoc """
  Client setup steps, registration requirements, and available setup actions

  Agent-assisted guides start with installation followed by authentication
  The catalog builds prompts only after registration and callback requirements hold
  """

  alias MmentumWeb.MCPClientGuides.Step

  @typedoc "Runtime-configured public client with id, name, redirect_uris, and optional setup_client"
  @type registration :: %{String.t() => String.t() | [String.t()]}
  @type state :: :ready | :registration_required | :callback_required | :manual_oauth_required
  @type t :: %__MODULE__{
          steps: [Step.t(), ...],
          requirements: String.t(),
          docs_url: String.t(),
          install_url: String.t() | {:vscode, String.t()} | nil,
          note: String.t() | nil,
          registration: registration() | nil,
          state: state(),
          agent_setup?: boolean(),
          agent_prompt: String.t() | nil
        }

  @enforce_keys [:steps, :requirements, :docs_url]
  defstruct [
    :steps,
    :requirements,
    :docs_url,
    :install_url,
    :note,
    :registration,
    :agent_prompt,
    state: :ready,
    agent_setup?: false
  ]
end
