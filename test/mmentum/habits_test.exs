defmodule Mmentum.HabitsTest do
  use Mmentum.DataCase

  alias Mmentum.Habits

  describe "habits" do
    alias Mmentum.Habits.Habit

    import Mmentum.HabitsFixtures
    import Mmentum.AccountsFixtures

    @invalid_attrs %{iterations: nil, name: nil, periodicity: nil}

    test "list_habits/1 returns all habits for user" do
      user = user_fixture()
      habit = habit_fixture(user: user)
      [returned_habit] = Habits.list_habits(user)
      assert returned_habit.id == habit.id
      assert returned_habit.name == habit.name
      assert returned_habit.logs == []
    end

    test "get_habit!/1 returns the habit with given id" do
      habit = habit_fixture()
      assert Habits.get_habit!(habit.id) == habit
    end

    test "create_habit/2 with valid data creates a habit" do
      user = user_fixture()
      valid_attrs = %{iterations: 42, name: "some name", periodicity: :week}

      assert {:ok, %Habit{} = habit} = Habits.create_habit(user, valid_attrs)
      assert habit.iterations == 42
      assert habit.name == "some name"
      assert habit.periodicity == :week
    end

    test "create_habit/2 with invalid data returns error changeset" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = Habits.create_habit(user, @invalid_attrs)
    end

    test "update_habit/2 with valid data updates the habit" do
      habit = habit_fixture()
      update_attrs = %{iterations: 43, name: "some updated name"}

      assert {:ok, %Habit{} = habit} = Habits.update_habit(habit, update_attrs)
      assert habit.iterations == 43
      assert habit.name == "some updated name"
    end

    test "update_habit/2 with invalid data returns error changeset" do
      habit = habit_fixture()
      assert {:error, %Ecto.Changeset{}} = Habits.update_habit(habit, @invalid_attrs)
      assert habit == Habits.get_habit!(habit.id)
    end

    test "delete_habit/1 deletes the habit" do
      habit = habit_fixture()
      assert {:ok, %Habit{}} = Habits.delete_habit(habit)
      assert_raise Ecto.NoResultsError, fn -> Habits.get_habit!(habit.id) end
    end

    test "change_habit/1 returns a habit changeset" do
      habit = habit_fixture()
      assert %Ecto.Changeset{} = Habits.change_habit(habit)
    end
  end
end
