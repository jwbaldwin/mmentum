defmodule MmentumWeb.HabitLiveTest do
  use MmentumWeb.ConnCase

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
               "Edit Habit"

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

    test "shows the habit's current periodicity when editing", %{conn: conn, habit: habit} do
      {:ok, habit} = Mmentum.Habits.update_habit(habit, %{periodicity: :month})
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
               "Edit Habit"

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
  end
end
