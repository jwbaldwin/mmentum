defmodule MmentumWeb.LogLiveTest do
  use MmentumWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mmentum.LogsFixtures

  defp create_log(%{user: user}) do
    log = log_fixture(user: user)
    %{log: log}
  end

  describe "Index" do
    setup [:register_and_log_in_user, :create_log]

    test "lists all logs", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/logs")

      assert html =~ "Listing Logs"
    end

    test "deletes log in listing", %{conn: conn, log: log} do
      {:ok, index_live, _html} = live(conn, ~p"/logs")

      assert index_live |> element(~s|#logs-#{log.id} a[phx-click]|) |> render_click()
      refute has_element?(index_live, "#logs-#{log.id}")
    end
  end

  describe "Show" do
    setup [:register_and_log_in_user, :create_log]

    test "displays log", %{conn: conn, log: log} do
      {:ok, _show_live, html} = live(conn, ~p"/logs/#{log}")

      assert html =~ "Show Log"
    end
  end
end
