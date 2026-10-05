defmodule Mmentum.HabitsFixtures do
  @moduledoc false

  def habit_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    user = attrs[:user] || Mmentum.AccountsFixtures.user_fixture()

    {:ok, habit} =
      attrs
      |> Map.delete(:user)
      |> Enum.into(%{
        min_completions: 3,
        name: "some name",
        periodicity: :week
      })
      |> then(&Mmentum.Habits.create_habit(user, &1))

    habit
  end
end
