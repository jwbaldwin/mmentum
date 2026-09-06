defmodule Mmentum.HabitsConcurrencyTest do
  use ExUnit.Case, async: false

  import Ecto.Query
  import Mmentum.AccountsFixtures
  import Mmentum.HabitsFixtures

  alias Ecto.Adapters.SQL.Sandbox
  alias Mmentum.Accounts.User
  alias Mmentum.Habits
  alias Mmentum.Habits.Habit
  alias Mmentum.Repo

  test "target edits wait for the habit lock before reading and validating the range" do
    supervisor = start_supervised!(Task.Supervisor)
    parent = self()

    Sandbox.unboxed_run(Repo, fn ->
      user = user_fixture()
      habit = habit_fixture(user: user, min_completions: 2, max_completions: 5)

      on_exit(fn ->
        Sandbox.unboxed_run(Repo, fn ->
          Repo.delete_all(from habit in Habit, where: habit.user_id == ^user.id)
          Repo.delete_all(from user in User, where: user.id == ^user.id)
        end)
      end)

      {:ok, edit} =
        Repo.transact(fn ->
          Repo.one!(from habit in Habit, where: habit.id == ^habit.id, lock: "FOR UPDATE")
          [[lock_owner]] = Repo.query!("SELECT pg_backend_pid()").rows

          edit =
            Task.Supervisor.async_nolink(supervisor, fn ->
              Sandbox.unboxed_run(Repo, fn ->
                [[backend]] = Repo.query!("SELECT pg_backend_pid()").rows
                send(parent, {:editing, backend})
                Habits.update_habit(user, habit.id, %{max_completions: 3})
              end)
            end)

          assert_receive {:editing, backend}
          query = wait_for_habit_lock(backend, lock_owner, System.monotonic_time(:millisecond) + 2000)
          assert query =~ "FOR UPDATE"
          assert {:ok, _habit} = Habits.update_habit(user, habit.id, %{min_completions: 4})
          {:ok, edit}
        end)

      assert {:error, changeset} = Task.await(edit)
      assert Mmentum.DataCase.errors_on(changeset).max_completions == ["must be greater than the minimum"]
      assert %{min_completions: 4, max_completions: 5} = Repo.get!(Habit, habit.id)
    end)
  end

  defp wait_for_habit_lock(backend, lock_owner, deadline) do
    [[query, blockers, _]] =
      Repo.query!(
        "SELECT query, pg_blocking_pids(pid), pg_stat_clear_snapshot() FROM pg_stat_activity WHERE pid = $1",
        [backend]
      ).rows

    if lock_owner in blockers do
      query
    else
      assert System.monotonic_time(:millisecond) < deadline, "target edit did not wait for the habit lock"
      wait_for_habit_lock(backend, lock_owner, deadline)
    end
  end
end
