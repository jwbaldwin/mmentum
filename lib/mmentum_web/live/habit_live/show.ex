defmodule MmentumWeb.HabitLive.Show do
  use MmentumWeb, :live_view

  import MmentumWeb.HabitComponents

  alias Mmentum.Habits
  alias Mmentum.Habits.Values.MomentumSeries
  alias Mmentum.Logs
  alias Mmentum.Time

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :period_timer, nil)}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign_habit(id)}
  end

  @impl true
  def handle_info(:period_boundary, socket) do
    {:noreply, assign_habit(socket, socket.assigns.habit.id)}
  end

  # The form's patch reloads the habit and reschedules its timer in handle_params/3
  def handle_info({MmentumWeb.HabitLive.FormComponent, {:saved, _habit}}, socket) do
    {:noreply, socket}
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
    momentum = MomentumSeries.build(habit, logs, current_time)

    period_timer =
      if connected?(socket) do
        if socket.assigns.period_timer, do: Process.cancel_timer(socket.assigns.period_timer)
        next_period = Time.next_start_of_range(current_time, habit.periodicity) |> DateTime.from_naive!("Etc/UTC")
        Process.send_after(self(), :period_boundary, DateTime.diff(next_period, current_time, :millisecond) + 1)
      end

    socket
    |> assign(:period_timer, period_timer)
    |> assign(:habit, habit)
    |> assign(:momentum, momentum)
    |> stream(:logs, logs |> Enum.reverse() |> Enum.take(5), reset: true)
  end

  defp page_title(:show), do: "Habit details"
  defp page_title(:edit), do: "Edit habit"
end
