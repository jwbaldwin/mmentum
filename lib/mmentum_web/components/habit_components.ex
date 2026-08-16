defmodule MmentumWeb.HabitComponents do
  use MmentumWeb, :html

  alias Mmentum.Habits.Habit

  attr :habit, Habit, required: true

  @doc """
  Simple component to display the habit's frequency range
  """
  def cadence(assigns) do
    ~H"""
    <%= if @habit.max_completions do %>
      {@habit.min_completions}–{@habit.max_completions} per {@habit.periodicity}
    <% else %>
      {@habit.min_completions} per {@habit.periodicity}
    <% end %>
    """
  end
end
