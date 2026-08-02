defmodule MmentumWeb.HabitLive.Index do
  use MmentumWeb, :live_view

  import MmentumWeb.HabitComponents

  alias Mmentum.Habits
  alias Mmentum.Habits.Habit
  alias Mmentum.Time

  @impl true
  def mount(_params, _session, socket) do
    if get_current_user(socket).time_zone do
      {:ok, assign_dashboard(socket)}
    else
      {:ok, assign(socket, habits: [], day_info: nil, greeting: nil, time_of_day: nil)}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    user = get_current_user(socket)

    socket
    |> assign(:page_title, "Edit habit")
    |> assign(:habit, Habits.get_habit!(user, id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New habit")
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
  def handle_event("add_log", %{"id" => habit_id}, socket) do
    case Habits.record_completion(get_current_user(socket), habit_id) do
      {:ok, _log} -> {:noreply, assign(socket, :habits, list_habits(socket))}
      {:error, :not_found} -> {:noreply, habit_not_found(socket)}
      {:error, %Ecto.Changeset{} = changeset} -> {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def handle_event("remove_log", %{"id" => habit_id}, socket) do
    case Habits.remove_most_recent_completion(get_current_user(socket), habit_id) do
      {:ok, _log} -> {:noreply, assign(socket, :habits, list_habits(socket))}
      {:error, :no_completion} -> {:noreply, socket}
      {:error, :not_found} -> {:noreply, habit_not_found(socket)}
      {:error, %Ecto.Changeset{} = changeset} -> {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp list_habits(socket) do
    user = get_current_user(socket)
    Habits.list_habits_with_range(user, Time.current_time(user.time_zone))
  end

  defp assign_dashboard(socket) do
    user = get_current_user(socket)
    current_time = Time.current_time(user.time_zone)

    assign(socket, %{
      habits: Habits.list_habits_with_range(user, current_time),
      day_info: build_day_info(current_time),
      greeting: greeting_for_time_of_day(user, current_time),
      time_of_day: Time.time_of_day(current_time)
    })
  end

  defp greeting_for_time_of_day(user, current_time) do
    first_name = user.full_name |> String.split() |> List.first() || "there"
    Time.greeting_for_time_of_day(current_time) <> ", " <> first_name
  end

  defp build_day_info(current_time) do
    current_day = Time.current_day(current_time)

    case Time.days_to_end(:week, current_time) do
      0 ->
        "Happy #{current_day}, a new week starts tomorrow!"

      2 ->
        "Happy #{current_day}, best day of the week!"

      6 ->
        "Happy #{current_day}, a fresh week ahead!"

      4 ->
        "Happy #{current_day}, make this hump-day count!"

      _ ->
        "Happy #{current_day}, keep your momentum going!"
    end
  end

  defp habit_not_found(socket), do: put_flash(socket, :error, "Habit not found.")
end
