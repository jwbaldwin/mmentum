defmodule MmentumWeb.HabitLiveTest do
  use MmentumWeb.ConnCase

  alias Mmentum.Habits
  alias Mmentum.Logs
  alias Mmentum.Logs.Log
  alias Mmentum.Repo

  import Phoenix.LiveViewTest
  import Mmentum.HabitsFixtures

  @create_attrs %{min_completions: 3, name: "some name"}
  @update_attrs %{
    identity: "I am someone who follows through",
    min_completions: 4,
    name: "some updated name",
    what_counts: "Twenty focused minutes",
    why_it_matters: "Consistency builds confidence"
  }
  @invalid_attrs %{min_completions: nil, name: nil}

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

    test "renders completion tooltips", %{conn: conn, habit: habit} do
      {:ok, index_live, _html} = live(conn, ~p"/habits")

      remove_tooltip =
        index_live
        |> element("#habit-#{habit.id}-remove-completion-tooltip[phx-hook=Tooltip]")
        |> render()

      assert remove_tooltip =~ ~s(data-tooltip-disabled="true")

      assert has_element?(
               index_live,
               "#habit-#{habit.id}-record-completion-tooltip[phx-hook=Tooltip][data-tooltip-content='Record completion']"
             )

      refute has_element?(index_live, "#habit-#{habit.id} button[title]")
    end

    test "uses accessible live navigation for shared authenticated links", %{conn: conn, user: user} do
      {:ok, index_live, _html} = live(conn, ~p"/habits")

      assert has_element?(index_live, ~s|header nav[aria-label="Primary"]|)

      assert has_element?(
               index_live,
               ~s|header a[href="/"][data-phx-link="redirect"][aria-label="Dashboard"] img[alt=""]|
             )

      assert has_element?(
               index_live,
               ~s|#account-menu summary[aria-label="Account menu for #{user.full_name}"]|
             )

      assert has_element?(
               index_live,
               ~s|#account-menu a[href="/users/settings"][data-phx-link="redirect"]|
             )

      assert has_element?(
               index_live,
               ~s|header #new-habit-button[href="/habits/new"][data-phx-link="redirect"]|
             )

      refute has_element?(index_live, "main #new-habit-button")
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
      {:ok, index_live, _html} = live(conn, ~p"/habits/new")

      refute has_element?(index_live, "#habit_max_completions")

      assert index_live
             |> form("#habit-form", habit: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert has_element?(index_live, "#habit_name[aria-invalid=true]")
      assert has_element?(index_live, "#habit_min_completions[aria-invalid=true]")

      assert index_live
             |> form("#habit-form", habit: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/habits")

      html = render(index_live)
      assert html =~ "Habit created."
      assert html =~ "some name"
    end

    test "saves a flexible range and treats its maximum as optional", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/habits/new")

      index_live
      |> form("#habit-form",
        habit: %{
          has_flexible_target: "true",
          min_completions: 2,
          name: "Go to the gym",
          periodicity: "week"
        }
      )
      |> render_change()

      assert has_element?(index_live, "#habit_max_completions")

      assert index_live
             |> form("#habit-form",
               habit: %{
                 has_flexible_target: "true",
                 max_completions: "",
                 min_completions: 2,
                 name: "Go to the gym",
                 periodicity: "week"
               }
             )
             |> render_submit() =~ "can&#39;t be blank"

      assert has_element?(index_live, "#habit_max_completions[aria-invalid=true]")

      index_live
      |> form("#habit-form",
        habit: %{
          has_flexible_target: "true",
          max_completions: 3,
          min_completions: 2,
          name: "Go to the gym",
          periodicity: "week"
        }
      )
      |> render_submit()

      assert_patch(index_live, ~p"/habits")
      html = render(index_live)
      assert html =~ "2–3 per week"

      habit = Repo.get_by!(Mmentum.Habits.Habit, name: "Go to the gym")
      progress = "#habit-#{habit.id}-progress"
      optional_step = "#habit-#{habit.id}-progress-step-3"
      add_button = ~s|#habit-#{habit.id} button[phx-click="add_log"]|

      assert has_element?(index_live, ~s|#{optional_step}[data-kind="optional"][data-state="pending"]|)
      assert has_element?(index_live, "#{progress} .habit-progress__optional-ring")

      index_live |> element(add_button) |> render_click()
      index_live |> element(add_button) |> render_click()

      assert has_element?(index_live, ~s|#{progress}[aria-valuenow="2"][aria-valuemax="2"]|)
      assert render(index_live) =~ "Goal met"
      assert has_element?(index_live, "#{add_button}:not([disabled])")

      index_live |> element(add_button) |> render_click()

      assert has_element?(index_live, ~s|#{optional_step}[data-state="complete"]|)
      refute has_element?(index_live, "#{progress} .habit-progress__optional-ring")

      assert has_element?(
               index_live,
               ~s|#{progress}[aria-valuetext="2 of 2 required completions; goal met; 1 of 1 optional completion completed"]|
             )

      assert has_element?(index_live, "#{add_button}[disabled]")
    end

    test "opens a habit from the dashboard", %{conn: conn, habit: habit} do
      {:ok, index_live, _html} = live(conn, ~p"/habits")

      index_live
      |> element(~s|#habit-#{habit.id} a[href="/habits/#{habit.id}"]|)
      |> render_click()

      assert_redirect(index_live, ~p"/habits/#{habit}")
    end

    test "shows what counts beneath the habit", %{conn: conn, habit: habit, user: user} do
      {:ok, habit} =
        Habits.update_habit(user, habit.id, %{what_counts: "Walk outside for ten minutes"})

      {:ok, index_live, _html} = live(conn, ~p"/habits")

      assert has_element?(index_live, "#habit-#{habit.id} p", habit.what_counts)
    end

    test "removes a flexible maximum when editing back to an exact target", %{
      conn: conn,
      habit: habit,
      user: user
    } do
      {:ok, habit} =
        Habits.update_habit(user, habit.id, %{min_completions: 2, max_completions: 3})

      {:ok, show_live, _html} = live(conn, ~p"/habits/#{habit}")

      show_live
      |> element("#edit-habit")
      |> render_click()

      assert has_element?(show_live, "#habit-has-flexible-target[checked]")
      assert has_element?(show_live, "#habit_max_completions")

      show_live
      |> form("#habit-form",
        habit: %{
          has_flexible_target: "false",
          min_completions: 2,
          name: habit.name,
          periodicity: "week"
        }
      )
      |> render_change()

      refute has_element?(show_live, "#habit_max_completions")

      show_live
      |> form("#habit-form",
        habit: %{
          has_flexible_target: "false",
          min_completions: 2,
          name: habit.name,
          periodicity: "week"
        }
      )
      |> render_submit()

      assert Repo.get!(Mmentum.Habits.Habit, habit.id).max_completions == nil
      assert render(show_live) =~ "2 per week"
    end

    test "shows the habit's current periodicity when editing", %{
      conn: conn,
      habit: habit,
      user: user
    } do
      {:ok, habit} = Habits.update_habit(user, habit.id, %{periodicity: :month})
      {:ok, show_live, _html} = live(conn, ~p"/habits/#{habit}")

      show_live
      |> element("#edit-habit")
      |> render_click()

      assert has_element?(show_live, "#habit_periodicity option[value=month][selected]")
    end

    test "marks the next progress segment complete after recording a completion", %{
      conn: conn,
      habit: habit
    } do
      {:ok, index_live, _html} = live(conn, ~p"/habits")
      progress = "#habit-#{habit.id}-progress"
      first_step = "#habit-#{habit.id}-progress-step-1"

      assert has_element?(index_live, ~s|#{progress}[data-completed="0"]|)
      assert has_element?(index_live, ~s|#{first_step}[data-state="pending"]|)

      index_live
      |> element(~s|#habit-#{habit.id} button[phx-click="add_log"]|)
      |> render_click()

      assert has_element?(index_live, ~s|#{progress}[data-completed="1"]|)

      assert has_element?(
               index_live,
               "#habit-#{habit.id}-progress-status[aria-live=polite][aria-atomic=true]",
               "1 of 3 completed"
             )

      assert has_element?(index_live, ~s|#{first_step}[data-state="complete"]|)
    end

    test "removes the user's most recent completion", %{conn: conn, habit: habit, user: user} do
      {:ok, log} = Habits.record_completion(user, habit.id)
      {:ok, index_live, _html} = live(conn, ~p"/habits")

      index_live
      |> element(~s|#habit-#{habit.id} button[phx-click="remove_log"]|)
      |> render_click()

      refute Repo.get(Mmentum.Logs.Log, log.id)
      assert has_element?(index_live, ~s|#habit-#{habit.id}-progress[data-completed="0"]|)
    end

    test "does not edit another user's habit", %{conn: conn} do
      habit = habit_fixture()

      assert_raise Ecto.NoResultsError, fn -> live(conn, ~p"/habits/#{habit}/edit") end
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

    test "displays the habit score, details, contribution history, and activity", %{
      conn: conn,
      habit: habit
    } do
      {:ok, show_live, html} = live(conn, ~p"/habits/#{habit}")

      assert html =~ "Habit details"
      assert html =~ habit.name
      assert has_element?(show_live, ~s|a[href="/habits"]|, "Today")
      assert has_element?(show_live, "header h1[class*='text-3xl']", habit.name)
      assert has_element?(show_live, "header", "3 per week")
      refute has_element?(show_live, "#habit-current-progress")
      assert has_element?(show_live, "#habit-mmentum #mmentum-score", "0")
      assert has_element?(show_live, "#mmentum-score-icon[src='/images/mmentum.svg']")
      assert has_element?(show_live, "#mmentum-score-title", "Mmentum")
      assert has_element?(show_live, "#habit-mmentum", "Grows with consistency")
      assert has_element?(show_live, "#habit-contributions-title", "Long-term progress")
      assert has_element?(show_live, "#habit-contribution-calendar[aria-label*='none recorded']")
      assert has_element?(show_live, "#habit-contribution-calendar time[datetime][title]")
      refute has_element?(show_live, "#habit-contribution-calendar time[tabindex]")

      refute has_element?(show_live, "#mmentum-score-tooltip")
      assert has_element?(show_live, "#habit-mmentum", "eases down between contributions")

      refute has_element?(show_live, "#record-habit-completion")
      refute has_element?(show_live, "#undo-habit-completion")
      assert has_element?(show_live, "#habit-meaning-title", "Habit details")
      assert has_element?(show_live, "#habit-meaning-empty", "Add an identity")
      assert has_element?(show_live, "#add-habit-details", "Add details")
      assert has_element?(show_live, "#habit-activity-title", "Recent activity")
      assert has_element?(show_live, "#habit-activity[phx-update='stream']")
      refute html =~ "Why it matters"
      refute html =~ "What counts"
    end

    test "shows the habit's identity and meaning", %{conn: conn, habit: habit, user: user} do
      {:ok, habit} =
        Habits.update_habit(user, habit.id, %{
          identity: "I am someone who takes care of my body",
          why_it_matters: "I want energy for the people I love",
          what_counts: "Complete the movement planned for today"
        })

      {:ok, show_live, html} = live(conn, ~p"/habits/#{habit}")

      assert has_element?(show_live, "header", "3 per week")
      assert has_element?(show_live, "#habit-identity", habit.identity)
      assert has_element?(show_live, "#habit-meaning", habit.why_it_matters)
      assert has_element?(show_live, "#habit-meaning", habit.what_counts)
      refute has_element?(show_live, "#habit-meaning-empty")
      assert html =~ "Habit details"
    end

    test "shows newest completion activity first and habit creation last", %{
      conn: conn,
      habit: habit,
      user: user
    } do
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      older_time = NaiveDateTime.add(now, -2, :day)
      newer_time = NaiveDateTime.add(now, -1, :day)

      older_log =
        Repo.insert!(%Log{
          habit_id: habit.id,
          inserted_at: older_time,
          updated_at: older_time,
          user_id: user.id
        })

      newer_log =
        Repo.insert!(%Log{
          habit_id: habit.id,
          inserted_at: newer_time,
          updated_at: newer_time,
          user_id: user.id
        })

      {:ok, show_live, _html} = live(conn, ~p"/habits/#{habit}")
      html = render(show_live)

      {newer_position, _length} = :binary.match(html, ~s|id="logs-#{newer_log.id}"|)
      {older_position, _length} = :binary.match(html, ~s|id="logs-#{older_log.id}"|)
      {creation_position, _length} = :binary.match(html, ~s|id="habit-created-#{habit.id}"|)

      assert newer_position < older_position
      assert older_position < creation_position
      assert has_element?(show_live, "#habit-contribution-calendar[aria-label*='2 completions across 2 days']")
    end

    test "updates habit within modal", %{conn: conn, habit: habit} do
      {:ok, show_live, _html} = live(conn, ~p"/habits/#{habit}")

      assert show_live |> element("#edit-habit") |> render_click() =~ "Edit habit"

      assert_patch(show_live, ~p"/habits/#{habit}/show/edit")

      assert show_live
             |> form("#habit-form", habit: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#habit-form", habit: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/habits/#{habit}")

      html = render(show_live)
      assert html =~ "Habit updated."
      assert html =~ "some updated name"
      assert html =~ @update_attrs.identity
      assert html =~ @update_attrs.why_it_matters
      assert html =~ @update_attrs.what_counts
    end

    test "deletes habit from its detail page", %{conn: conn, habit: habit} do
      {:ok, show_live, _html} = live(conn, ~p"/habits/#{habit}")

      show_live
      |> element(~s|button[phx-click="delete"]|)
      |> render_click()

      assert_redirect(show_live, ~p"/habits")
      refute Repo.get(Mmentum.Habits.Habit, habit.id)
    end

    test "does not show or edit another user's habit", %{conn: conn} do
      habit = habit_fixture()

      assert_raise Ecto.NoResultsError, fn -> live(conn, ~p"/habits/#{habit}") end
      assert_raise Ecto.NoResultsError, fn -> live(conn, ~p"/habits/#{habit}/show/edit") end
    end
  end
end
