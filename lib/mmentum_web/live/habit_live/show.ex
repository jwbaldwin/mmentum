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

  defp page_title(:show), do: "Habit details"
  defp page_title(:edit), do: "Edit habit"

  defp target_description(%{max_completions: nil} = habit) do
    unit = if habit.min_completions == 1, do: "time", else: "times"
    "#{habit.min_completions} #{unit} per #{habit.periodicity}"
  end

  defp target_description(habit) do
    "#{habit.min_completions}–#{habit.max_completions} times per #{habit.periodicity}"
  end
end
