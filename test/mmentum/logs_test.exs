defmodule Mmentum.LogsTest do
  use Mmentum.DataCase

  alias Mmentum.Logs
  alias Mmentum.Logs.Log
  alias Mmentum.Repo

  import Mmentum.AccountsFixtures
  import Mmentum.HabitsFixtures
  import Mmentum.LogsFixtures

  describe "completion activity" do
    test "list_logs_by_habit/2 returns an owned habit's activity" do
      user = user_fixture()
      habit = habit_fixture(user: user)
      log = log_fixture(user: user, habit: habit)

      assert Logs.list_logs_by_habit(user, habit) == [log]
    end

    test "list_logs_by_habit/2 does not reveal another user's activity" do
      owner = user_fixture()
      attacker = user_fixture()
      habit = habit_fixture(user: owner)
      _log = log_fixture(user: owner, habit: habit)

      assert Logs.list_logs_by_habit(attacker, habit) == []
    end

    test "inconsistent ownership is visible to neither user" do
      owner = user_fixture()
      other_user = user_fixture()
      habit = habit_fixture(user: owner)
      Repo.insert!(%Log{user_id: other_user.id, habit_id: habit.id})

      assert Logs.list_logs_by_habit(owner, habit) == []
      assert Logs.list_logs_by_habit(other_user, habit) == []
    end
  end
end
