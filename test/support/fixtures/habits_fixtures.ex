defmodule Mmentum.HabitsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Mmentum.Habits` context.
  """

  @doc """
  Generate a habit.
  """
  def habit_fixture(attrs \\ %{}) do
    attrs = Enum.into(attrs, %{})
    user = attrs[:user] || Mmentum.AccountsFixtures.user_fixture()

    {:ok, habit} =
      attrs
      |> Map.drop([:user])
      |> Enum.into(%{
        iterations: 42,
        name: "some name",
        periodicity: :week
      })
      |> then(&Mmentum.Habits.create_habit(user, &1))

    habit
  end
end
