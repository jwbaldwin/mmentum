defmodule MmentumWeb.HabitLive.FormComponent do
  use MmentumWeb, :live_component

  alias Mmentum.Habits

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <header class="pr-8 sm:pr-10">
        <h1 class="mt-2 text-2xl font-semibold tracking-tight text-zinc-900">
          {if @action == :new, do: "Who are you?", else: "Refine"}
        </h1>
        <p class="mt-2 text-sm leading-6 text-zinc-500">
          {if @action == :new,
            do: "Every action is a vote for who you want to be",
            else: "Adjust your habit"}
        </p>
      </header>

      <.form
        for={@form}
        id="habit-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        class="mt-7 space-y-6"
      >
        <.input
          field={@form[:name]}
          type="text"
          label="I am becoming someone who..."
          placeholder="e.g. reads before bed"
          autocomplete="off"
          class="h-12 rounded-xl bg-zinc-50/60 px-4 text-base shadow-none placeholder:text-zinc-400 focus:bg-white focus:ring-4 focus:ring-zinc-900/5"
        />

        <fieldset class="rounded-2xl border border-zinc-200 bg-zinc-50/70 p-4">
          <legend class="px-1 text-sm font-semibold text-zinc-900">Cadence</legend>
          <div class="grid grid-cols-1 gap-3 sm:grid-cols-[9rem_1fr]">
            <.input
              field={@form[:iterations]}
              type="number"
              label="Votes"
              max={31}
              min={1}
              class="h-11 rounded-xl bg-white px-3 text-center text-base font-medium shadow-sm focus:ring-4 focus:ring-zinc-900/5"
            />
            <.input
              field={@form[:periodicity]}
              type="select"
              label="Per"
              options={[Day: :day, Week: :week, Month: :month]}
              class="h-11 rounded-xl bg-white py-0 pl-3 pr-9 text-base font-medium shadow-sm focus:ring-4 focus:ring-zinc-900/5"
            />
          </div>
        </fieldset>

        <.button
          phx-disable-with="Saving..."
          class="flex h-12 w-full items-center justify-center gap-2 rounded-xl text-base shadow-sm hover:shadow-md focus:outline-none focus:ring-2 focus:ring-zinc-900 focus:ring-offset-2"
        >
          {if @action == :new, do: "Start becoming", else: "Save changes"}
          <.icon name="hero-arrow-right-mini" class="h-4 w-4" />
        </.button>
      </.form>
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
    case Habits.update_habit(get_current_user(socket), socket.assigns.habit.id, habit_params) do
      {:ok, habit} ->
        notify_parent({:saved, habit})

        {:noreply,
         socket
         |> put_flash(:success, "Habit updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "Habit not found")
         |> push_patch(to: socket.assigns.patch)}
    end
  end

  defp save_habit(socket, :new, habit_params) do
    user = get_current_user(socket)

    case Habits.create_habit(user, habit_params) do
      {:ok, habit} ->
        notify_parent({:saved, habit})

        {:noreply,
         socket
         |> put_flash(:success, "Habit created successfully")
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
