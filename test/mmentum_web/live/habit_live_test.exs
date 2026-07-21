defmodule MmentumWeb.HabitLiveTest do
  use MmentumWeb.ConnCase

  alias Mmentum.Habits
  alias Mmentum.Logs
  alias Mmentum.Repo

  import Phoenix.LiveViewTest
  import Mmentum.HabitsFixtures

  @create_attrs %{iterations: 42, name: "some name"}
  @update_attrs %{iterations: 43, name: "some updated name"}
  @invalid_attrs %{iterations: nil, name: nil}

  defp create_habit(%{user: user}) do
    habit = habit_fixture(user: user)
    %{habit: habit}
  end

  describe "Index" do
    setup [:register_and_log_in_user, :create_habit]

    test "saves the browser time zone once", %{conn: conn, user: user} do
      {:ok, user} = Mmentum.Accounts.update_user_time_zone(user, nil)
      conn = log_in_user(conn, user)

      conn
      |> put_connect_params(%{"time_zone" => "America/New_York"})
      |> live(~p"/habits")

      assert Mmentum.Accounts.get_user!(user.id).time_zone == "America/New_York"

      conn
      |> put_connect_params(%{"time_zone" => "America/Chicago"})
      |> live(~p"/habits")

      assert Mmentum.Accounts.get_user!(user.id).time_zone == "America/New_York"
    end

    test "lists all habits", %{conn: conn, habit: habit} do
      {:ok, _index_live, html} = live(conn, ~p"/habits")

      assert html =~ habit.name
    end

    test "greets users with one-word and multi-part names" do
      for {full_name, first_name} <- [{"Prince", "Prince"}, {"James Earl Jones", "James"}] do
        user = Mmentum.AccountsFixtures.user_fixture(%{full_name: full_name})

        {:ok, _index_live, html} =
          build_conn()
          |> log_in_user(user)
          |> live(~p"/habits")

        assert html =~ ", #{first_name}!"
      end
    end

    test "renders safely for a legacy blank name" do
      user = Mmentum.AccountsFixtures.user_fixture()
      user = user |> Ecto.Changeset.change(full_name: "") |> Mmentum.Repo.update!()

      {:ok, _index_live, html} =
        build_conn()
        |> log_in_user(user)
        |> live(~p"/habits")

      assert html =~ ", there!"
    end

    test "saves new habit", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/habits")

      assert index_live |> element(~s|a[href="/habits/new"]|) |> render_click() =~
               "New habit"

      assert_patch(index_live, ~p"/habits/new")

      assert index_live
             |> form("#habit-form", habit: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert has_element?(index_live, "#habit_name[aria-invalid=true]")
      assert has_element?(index_live, "#habit_iterations[aria-invalid=true]")

      assert index_live
             |> form("#habit-form", habit: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/habits")

      html = render(index_live)
      assert html =~ "Habit created successfully"
      assert html =~ "some name"
    end

    test "updates habit in listing", %{conn: conn, habit: habit} do
      {:ok, index_live, _html} = live(conn, ~p"/habits")

      assert index_live
             |> element(~s|#habit-#{habit.id} a[href="/habits/#{habit.id}/edit"]|)
             |> render_click() =~
               "Refine"

      assert_patch(index_live, ~p"/habits/#{habit}/edit")

      assert index_live
             |> form("#habit-form", habit: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#habit-form", habit: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/habits")

      html = render(index_live)
      assert html =~ "Habit updated successfully"
      assert html =~ "some updated name"
    end

    test "shows the habit's current periodicity when editing", %{
      conn: conn,
      habit: habit,
      user: user
    } do
      {:ok, habit} = Habits.update_habit(user, habit.id, %{periodicity: :month})
      {:ok, index_live, _html} = live(conn, ~p"/habits")

      index_live
      |> element(~s|#habit-#{habit.id} a[href="/habits/#{habit.id}/edit"]|)
      |> render_click()

      assert has_element?(index_live, "#habit_periodicity option[value=month][selected]")
    end

    test "deletes habit in listing", %{conn: conn, habit: habit} do
      {:ok, index_live, _html} = live(conn, ~p"/habits")

      assert index_live
             |> element(~s|#habit-#{habit.id} button[phx-click="delete"]|)
             |> render_click()

      refute has_element?(index_live, "#habit-#{habit.id}")
    end

    test "does not edit another user's habit", %{conn: conn} do
      habit = habit_fixture()

      assert_raise Ecto.NoResultsError, fn -> live(conn, ~p"/habits/#{habit}/edit") end
    end

    test "does not delete another user's habit", %{conn: conn} do
      habit = habit_fixture()
      {:ok, index_live, _html} = live(conn, ~p"/habits")

      assert render_hook(index_live, "delete", %{"id" => habit.id}) =~ "Habit not found."
      assert Repo.get!(Mmentum.Habits.Habit, habit.id)
    end

    test "does not add or remove another user's completions", %{conn: conn} do
      owner = Mmentum.AccountsFixtures.user_fixture()
      habit = habit_fixture(user: owner)
      {:ok, log} = Habits.record_completion(owner, habit.id)
      {:ok, index_live, _html} = live(conn, ~p"/habits")

      assert render_hook(index_live, "add_log", %{"id" => habit.id}) =~ "Habit not found."
      assert render_hook(index_live, "remove_log", %{"id" => habit.id}) =~ "Habit not found."
      assert Logs.list_logs_by_habit(owner, habit) == [log]
    end
  end

  describe "Show" do
    setup [:register_and_log_in_user, :create_habit]

    test "displays habit", %{conn: conn, habit: habit} do
      {:ok, _show_live, html} = live(conn, ~p"/habits/#{habit}")

      assert html =~ "Show Habit"
      assert html =~ habit.name
    end

    test "updates habit within modal", %{conn: conn, habit: habit} do
      {:ok, show_live, _html} = live(conn, ~p"/habits/#{habit}")

      assert show_live |> element(~s|a[href="/habits/#{habit.id}/show/edit"]|) |> render_click() =~
               "Refine"

      assert_patch(show_live, ~p"/habits/#{habit}/show/edit")

      assert show_live
             |> form("#habit-form", habit: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#habit-form", habit: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/habits/#{habit}")

      html = render(show_live)
      assert html =~ "Habit updated successfully"
      assert html =~ "some updated name"
    end

    test "does not show or edit another user's habit", %{conn: conn} do
      habit = habit_fixture()

      assert_raise Ecto.NoResultsError, fn -> live(conn, ~p"/habits/#{habit}") end
      assert_raise Ecto.NoResultsError, fn -> live(conn, ~p"/habits/#{habit}/show/edit") end
    end
  end
end
