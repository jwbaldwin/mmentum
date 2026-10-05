defmodule Mmentum.LogsFixtures do
  @moduledoc false

  def log_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    user = attrs[:user] || Mmentum.AccountsFixtures.user_fixture()
    habit = attrs[:habit] || Mmentum.HabitsFixtures.habit_fixture(user: user)

    {:ok, log} = Mmentum.Habits.record_completion(user, habit.id)

    log
  end
end
