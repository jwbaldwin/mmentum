defmodule Mmentum.HabitsTest do
  use Mmentum.DataCase

  alias Mmentum.Habits
  alias Mmentum.Habits.Habit
  alias Mmentum.Logs
  alias Mmentum.Logs.Log
  alias Mmentum.Repo

  import Mmentum.AccountsFixtures
  import Mmentum.HabitsFixtures

  @invalid_attrs %{min_completions: nil, name: nil, periodicity: nil}

  describe "habits" do
    test "get_habit!/2 returns an owned habit" do
      user = user_fixture()
      habit = habit_fixture(user: user)

      assert Habits.get_habit!(user, habit.id) == habit
    end

    test "get_habit!/2 does not reveal another user's habit" do
      attacker = user_fixture()
      habit = habit_fixture()

      assert_raise Ecto.NoResultsError, fn -> Habits.get_habit!(attacker, habit.id) end
      assert_raise Ecto.NoResultsError, fn -> Habits.get_habit!(attacker, -1) end
    end

    test "get_habit_with_current_progress!/3 preloads current completion activity" do
      user = user_fixture()
      habit = habit_fixture(user: user)
      {:ok, log} = Habits.record_completion(user, habit.id)

      habit =
        Habits.get_habit_with_current_progress!(
          user,
          habit.id,
          Mmentum.Time.current_time(user.time_zone)
        )

      assert habit.logs == [log]
    end

    test "create_habit/2 creates a habit for the user" do
      user = user_fixture()
      valid_attrs = %{min_completions: 3, name: "some name", periodicity: :week}

      assert {:ok, %Habit{} = habit} = Habits.create_habit(user, valid_attrs)
      assert habit.user_id == user.id
      assert habit.min_completions == 3
      assert habit.max_completions == nil
      assert habit.name == "some name"
      assert habit.periodicity == :week
    end

    test "create_habit/2 creates a flexible completion range" do
      user = user_fixture()

      assert {:ok, %Habit{} = habit} =
               Habits.create_habit(user, %{
                 min_completions: 2,
                 max_completions: 3,
                 name: "Go to the gym",
                 periodicity: :week
               })

      assert habit.min_completions == 2
      assert habit.max_completions == 3
    end

    test "create_habit/2 rejects a maximum that does not exceed the minimum" do
      attrs = %{
        min_completions: 2,
        max_completions: 2,
        name: "Go to the gym",
        periodicity: :week
      }

      assert {:error, changeset} = Habits.create_habit(user_fixture(), attrs)
      assert "must be greater than the minimum" in errors_on(changeset).max_completions
    end

    test "create_habit/2 returns an error changeset for invalid data" do
      assert {:error, %Ecto.Changeset{}} = Habits.create_habit(user_fixture(), @invalid_attrs)
    end

    test "update_habit/3 updates an owned habit" do
      user = user_fixture()
      habit = habit_fixture(user: user)

      assert {:ok, %Habit{} = habit} =
               Habits.update_habit(user, habit.id, %{min_completions: 4, name: "updated"})

      assert habit.min_completions == 4
      assert habit.name == "updated"
    end

    test "update_habit/3 returns an error changeset for invalid data" do
      user = user_fixture()
      habit = habit_fixture(user: user)

      assert {:error, %Ecto.Changeset{}} = Habits.update_habit(user, habit.id, @invalid_attrs)
      assert habit == Habits.get_habit!(user, habit.id)
    end

    test "update_habit/3 does not update another user's habit" do
      attacker = user_fixture()
      habit = habit_fixture()

      assert {:error, :not_found} = Habits.update_habit(attacker, habit.id, %{name: "stolen"})
      assert Repo.get!(Habit, habit.id).name == habit.name
    end

    test "delete_habit/2 deletes an owned habit" do
      user = user_fixture()
      habit = habit_fixture(user: user)

      assert {:ok, %Habit{}} = Habits.delete_habit(user, habit.id)
      assert_raise Ecto.NoResultsError, fn -> Habits.get_habit!(user, habit.id) end
    end

    test "delete_habit/2 does not delete another user's habit" do
      attacker = user_fixture()
      habit = habit_fixture()

      assert {:error, :not_found} = Habits.delete_habit(attacker, habit.id)
      assert Repo.get!(Habit, habit.id)
    end

    test "change_habit/1 returns a habit changeset" do
      assert %Ecto.Changeset{} = Habits.change_habit(habit_fixture())
    end
  end

  describe "completions" do
    test "record_completion/2 derives ownership and updates momentum" do
      user = user_fixture()
      habit = habit_fixture(user: user)

      assert {:ok, %Log{} = log} = Habits.record_completion(user, habit.id)
      assert log.user_id == user.id
      assert log.habit_id == habit.id
      assert Repo.get!(Habit, habit.id).momentum_score > 0
    end

    test "record_completion/2 does not add activity to another user's habit" do
      attacker = user_fixture()
      habit = habit_fixture()

      assert {:error, :not_found} = Habits.record_completion(attacker, habit.id)
      assert Repo.aggregate(Log, :count) == 0
      assert Repo.get!(Habit, habit.id).momentum_score == habit.momentum_score
    end

    test "remove_most_recent_completion/2 removes only the latest owned completion" do
      user = user_fixture()
      habit = habit_fixture(user: user)
      {:ok, first_log} = Habits.record_completion(user, habit.id)
      {:ok, second_log} = Habits.record_completion(user, habit.id)

      assert {:ok, removed_log} = Habits.remove_most_recent_completion(user, habit.id)
      assert removed_log.id == second_log.id
      assert [remaining_log] = Logs.list_logs_by_habit(user, habit)
      assert remaining_log.id == first_log.id
    end

    test "remove_most_recent_completion/2 leaves an empty habit unchanged" do
      user = user_fixture()
      habit = habit_fixture(user: user)

      assert {:error, :no_completion} = Habits.remove_most_recent_completion(user, habit.id)
      assert Repo.get!(Habit, habit.id).momentum_score == habit.momentum_score
    end

    test "remove_most_recent_completion/2 does not remove another user's activity" do
      owner = user_fixture()
      attacker = user_fixture()
      habit = habit_fixture(user: owner)
      {:ok, log} = Habits.record_completion(owner, habit.id)

      assert {:error, :not_found} = Habits.remove_most_recent_completion(attacker, habit.id)
      assert Repo.get!(Log, log.id)
    end
  end
end
