defmodule MmentumWeb.HabitLive.Show do
  use MmentumWeb, :live_view

  import MmentumWeb.HabitComponents

  alias Mmentum.Habits
  alias Mmentum.Habits.Values.ContributionCalendar
  alias Mmentum.Logs
  alias Mmentum.Time

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign_habit(id)}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    case Habits.delete_habit(get_current_user(socket), socket.assigns.habit.id) do
      {:ok, _habit} ->
        {:noreply,
         socket
         |> put_flash(:info, "Habit deleted.")
         |> push_navigate(to: ~p"/habits")}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "Habit not found.")
         |> push_navigate(to: ~p"/habits")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp assign_habit(socket, habit_id) do
    user = get_current_user(socket)
    current_time = Time.current_time(user.time_zone)
    habit = Habits.get_habit!(user, habit_id)
    logs = Logs.list_logs_by_habit(user, habit)

    socket
    |> assign(:habit, habit)
    |> assign(:contribution_calendar, ContributionCalendar.build(logs, current_time))
    |> assign(:momentum, round(Habits.get_current_momentum(habit)))
    |> stream(:logs, logs |> Enum.reverse() |> Enum.take(5), reset: true)
  end

  defp page_title(:show), do: "Habit details"
  defp page_title(:edit), do: "Edit habit"
end
