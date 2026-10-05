defmodule Mmentum.Tools.Context do
  @moduledoc """
  Server-supplied identity, permissions, and time for one tool invocation

  The transport supplies these values after authentication, never from tool arguments
  `now` is one captured instant; each tool resolves the user's local calendar
  """

  alias Mmentum.Accounts.User
  alias Mmentum.Tools.Scope

  @type t :: %{user: User.t(), scopes: [Scope.t()], now: DateTime.t()}
end
