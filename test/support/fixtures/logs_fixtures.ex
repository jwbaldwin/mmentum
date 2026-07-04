defmodule Mmentum.LogsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Mmentum.Logs` context.
  """

  @doc """
  Generate a log.
  """
  def log_fixture(attrs \\ %{}) do
    attrs = Enum.into(attrs, %{})
    user = attrs[:user] || Mmentum.AccountsFixtures.user_fixture()
    habit = attrs[:habit] || Mmentum.HabitsFixtures.habit_fixture(user: user)

    {:ok, log} =
      attrs
      |> Map.drop([:user, :habit])
      |> Enum.into(%{user_id: user.id, habit_id: habit.id})
      |> Mmentum.Logs.create_log()

    log
  end
end
