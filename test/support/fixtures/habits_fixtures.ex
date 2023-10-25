defmodule Mmentum.HabitsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Mmentum.Habits` context.
  """

  @doc """
  Generate a habit.
  """
  def habit_fixture(attrs \\ %{}) do
    {:ok, habit} =
      attrs
      |> Enum.into(%{
        iterations: 42,
        name: "some name"
      })
      |> Mmentum.Habits.create_habit()

    habit
  end
end
