defmodule MmentumWeb.HabitLive.Show do
  use MmentumWeb, :live_view

  alias Mmentum.Habits
  alias Mmentum.Logs
  alias Mmentum.Time

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    user = get_current_user(socket)
    habit = Habits.get_habit!(user, id)

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:habit, habit)
     |> stream(:logs, Logs.list_logs_by_habit(user, habit))}
  end

  defp page_title(:show), do: "Show Habit"
  defp page_title(:edit), do: "Edit Habit"
end
