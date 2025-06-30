defmodule MmentumWeb.HabitLive.Index do
  use MmentumWeb, :live_view

  alias Mmentum.Habits
  alias Mmentum.Habits.Habit
  alias Mmentum.Logs
  alias Mmentum.Time

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:habits, list_habits(socket))
     |> assign_day_info()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Habit")
    |> assign(:habit, Habits.get_habit!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Habit")
    |> assign(:habit, %Habit{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Dashboard")
    |> assign(:habit, nil)
  end

  @impl true
  def handle_info({MmentumWeb.HabitLive.FormComponent, {:saved, _habit}}, socket) do
    {:noreply, assign(socket, :habits, list_habits(socket))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    habit = Habits.get_habit!(id)
    {:ok, _} = Habits.delete_habit(habit)

    {:noreply, assign(socket, :habits, list_habits(socket))}
  end

  def handle_event("add_log", %{"id" => habit_id}, socket) do
    user = get_current_user(socket)

    case Logs.create_log(%{user_id: user.id, habit_id: habit_id}) do
      {:ok, _log} ->
        habit = Habits.get_habit!(habit_id)
        Habits.update_momentum_on_log_added(habit)

        {:noreply, assign(socket, :habits, list_habits(socket))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def handle_event("remove_log", %{"id" => habit_id}, socket) do
    habit_id
    |> Logs.delete_most_recent_log()
    |> case do
      {:ok, _} ->
        # TODO: don't do this here man... this should be a multi...
        # also it doesn't even work when deleting logs?
        habit = Habits.get_habit!(habit_id)
        Habits.update_momentum_on_log_removed(habit)

        {:noreply, assign(socket, :habits, list_habits(socket))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp list_habits(socket) do
    habits =
      socket
      |> get_current_user()
      |> Habits.list_habits_with_range()
  end

  defp assign_day_info(socket) do
    assign(socket, %{
      day_info: build_day_info(),
      current_time: Time.current_time(),
      greeting: greeting_for_time_of_day(socket),
      time_of_day: Time.time_of_day()
    })
  end

  defp greeting_for_time_of_day(socket) do
    user = get_current_user(socket)
    [partial_name, _rest] = String.split(user.full_name, " ")
    Time.greeting_for_time_of_day() <> ", " <> partial_name
  end

  defp build_day_info do
    current_day = Time.current_day()

    case Time.days_to_end(:week) do
      0 ->
        "Happy #{current_day}, a new week starts tomorrow!"

      2 ->
        "Happy #{current_day}, best day of the week!"

      6 ->
        "Happy #{current_day}, a fresh week ahead!"

      4 ->
        "Happy #{current_day}, make this hump-day count!"
    end
  end
end
