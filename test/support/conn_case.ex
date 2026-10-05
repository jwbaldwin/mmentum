defmodule MmentumWeb.ConnCase do
  @moduledoc "Builds test connections with sandboxed database access and session helpers"

  use ExUnit.CaseTemplate
  use Boundary, top_level?: true, check: [in: false, out: false]

  using do
    quote do
      use MmentumWeb, :verified_routes

      import MmentumWeb.ConnCase
      import Phoenix.ConnTest

      # Import conveniences for testing with connections
      import Plug.Conn

      # The default endpoint for testing
      @endpoint MmentumWeb.Endpoint
    end
  end

  setup tags do
    Mmentum.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Setup helper that registers and logs in users.

      setup :register_and_log_in_user

  It stores an updated connection and a registered user in the
  test context.
  """
  def register_and_log_in_user(%{conn: conn}) do
    user = Mmentum.AccountsFixtures.user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  @doc """
  Logs the given `user` into the `conn`.

  It returns an updated `conn`.
  """
  def log_in_user(conn, user) do
    token = Mmentum.Accounts.generate_user_session_token(user)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end
end
