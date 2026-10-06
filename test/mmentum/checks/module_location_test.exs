Code.require_file("../../../lib/mmentum/checks/module_location.exs", __DIR__)

defmodule Mmentum.Checks.ModuleLocationTest do
  use ExUnit.Case, async: true

  alias Credo.SourceFile
  alias Credo.Test.CheckRunner
  alias Mmentum.Checks.ModuleLocation

  setup_all do
    {:ok, _} = Application.ensure_all_started(:credo)
    :ok
  end

  test "accepts matching module paths for application code and checks" do
    assert issues("Mmentum.Habits.Values.Habit", "lib/mmentum/habits/values/habit.ex") == []
    assert issues("Mmentum.Checks.EntityValue", "lib/mmentum/checks/entity_value.exs") == []
  end

  test "rejects a misplaced application module" do
    assert [%{message: "Place this module in lib/mmentum/habits/habit.ex"}] =
             issues("Mmentum.Habits.Habit", "lib/habits/habit.ex")
  end

  test "rejects a check whose namespace is missing from its path" do
    assert [%{message: "Place this module in lib/mmentum_checks/entity_value.exs"}] =
             issues("MmentumChecks.EntityValue", "lib/checks/entity_value.exs")
  end

  test "leaves test and migration file conventions alone" do
    assert issues("Mmentum.HabitsTest", "test/mmentum/habits_test.exs") == []
    assert issues("Mmentum.Repo.Migrations.CreateHabits", "priv/repo/migrations/20260101000000_create_habits.exs") == []
  end

  test "recognizes Phoenix's namespace-free grouping directories" do
    assert issues("MmentumWeb.HabitLive.Index", "lib/mmentum_web/live/habit_live/index.ex") == []
    assert issues("MmentumWeb.UserSessionController", "lib/mmentum_web/controllers/user_session_controller.ex") == []
    assert issues("MmentumWeb.CoreComponents", "lib/mmentum_web/components/core_components.ex") == []
    assert [_] = issues("MmentumWeb.CoreComponents", "lib/mmentum_web/components/wrong.ex")
  end

  test "recognizes the project's OAuth spelling" do
    assert issues("Mmentum.OAuth.Connection", "lib/mmentum/oauth/connection.ex") == []
    assert issues("MmentumWeb.Plugs.RequireOAuthHTTPS", "lib/mmentum_web/plugs/require_oauth_https.ex") == []
  end

  defp issues(module, path) do
    "defmodule #{module} do end"
    |> SourceFile.parse(path)
    |> CheckRunner.run_check(ModuleLocation)
  end
end
