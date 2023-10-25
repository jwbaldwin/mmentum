defmodule MmentumWeb.LogLiveTest do
  use MmentumWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mmentum.LogsFixtures

  @create_attrs %{}
  @update_attrs %{}
  @invalid_attrs %{}

  defp create_log(_) do
    log = log_fixture()
    %{log: log}
  end

  describe "Index" do
    setup [:create_log]

    test "lists all logs", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/logs")

      assert html =~ "Listing Logs"
    end

    test "saves new log", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/logs")

      assert index_live |> element("a", "New Log") |> render_click() =~
               "New Log"

      assert_patch(index_live, ~p"/logs/new")

      assert index_live
             |> form("#log-form", log: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#log-form", log: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/logs")

      html = render(index_live)
      assert html =~ "Log created successfully"
    end

    test "updates log in listing", %{conn: conn, log: log} do
      {:ok, index_live, _html} = live(conn, ~p"/logs")

      assert index_live |> element("#logs-#{log.id} a", "Edit") |> render_click() =~
               "Edit Log"

      assert_patch(index_live, ~p"/logs/#{log}/edit")

      assert index_live
             |> form("#log-form", log: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#log-form", log: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/logs")

      html = render(index_live)
      assert html =~ "Log updated successfully"
    end

    test "deletes log in listing", %{conn: conn, log: log} do
      {:ok, index_live, _html} = live(conn, ~p"/logs")

      assert index_live |> element("#logs-#{log.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#logs-#{log.id}")
    end
  end

  describe "Show" do
    setup [:create_log]

    test "displays log", %{conn: conn, log: log} do
      {:ok, _show_live, html} = live(conn, ~p"/logs/#{log}")

      assert html =~ "Show Log"
    end

    test "updates log within modal", %{conn: conn, log: log} do
      {:ok, show_live, _html} = live(conn, ~p"/logs/#{log}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Log"

      assert_patch(show_live, ~p"/logs/#{log}/show/edit")

      assert show_live
             |> form("#log-form", log: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#log-form", log: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/logs/#{log}")

      html = render(show_live)
      assert html =~ "Log updated successfully"
    end
  end
end
