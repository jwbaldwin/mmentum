defmodule MmentumWeb.HabitLive.FormComponent do
  use MmentumWeb, :live_component

  alias Mmentum.Habits

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Use this form to manage habit records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="habit-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:iterations]} type="number" label="Iterations" />
        <:actions>
          <.button phx-disable-with="Saving...">Save Habit</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{habit: habit} = assigns, socket) do
    changeset = Habits.change_habit(habit)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"habit" => habit_params}, socket) do
    changeset =
      socket.assigns.habit
      |> Habits.change_habit(habit_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"habit" => habit_params}, socket) do
    save_habit(socket, socket.assigns.action, habit_params)
  end

  defp save_habit(socket, :edit, habit_params) do
    case Habits.update_habit(socket.assigns.habit, habit_params) do
      {:ok, habit} ->
        notify_parent({:saved, habit})

        {:noreply,
         socket
         |> put_flash(:info, "Habit updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_habit(socket, :new, habit_params) do
    case Habits.create_habit(habit_params) do
      {:ok, habit} ->
        notify_parent({:saved, habit})

        {:noreply,
         socket
         |> put_flash(:info, "Habit created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
