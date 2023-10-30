defmodule MmentumWeb.HabitLive.Index do
  use MmentumWeb, :live_view

  alias Mmentum.Habits
  alias Mmentum.Habits.Habit
  alias Mmentum.Time

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> stream(:habits, Habits.list_habits())
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
  def handle_info({MmentumWeb.HabitLive.FormComponent, {:saved, habit}}, socket) do
    {:noreply, stream_insert(socket, :habits, habit)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    habit = Habits.get_habit!(id)
    {:ok, _} = Habits.delete_habit(habit)

    {:noreply, stream_delete(socket, :habits, habit)}
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

      2 = days_until_end_of_week ->
        "Happy #{current_day}, the weekend is close! #{days_until_end_of_week} days left in the week."

      days_until_end_of_week ->
        "Happy #{current_day}, the week ends in #{days_until_end_of_week} days"
    end
  end
end
