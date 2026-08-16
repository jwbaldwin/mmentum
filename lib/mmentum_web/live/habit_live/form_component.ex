defmodule MmentumWeb.HabitLive.FormComponent do
  use MmentumWeb, :live_component

  alias Mmentum.Habits

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <header class="pr-8 sm:pr-10">
        <h2 id="habit-modal-title" class="text-2xl font-semibold leading-8 tracking-tight text-zinc-900 dark:text-zinc-100">
          {if @action == :new, do: "New habit", else: "Edit habit"}
        </h2>
        <p
          id="habit-modal-description"
          class="mt-2 text-sm font-normal leading-6 text-muted dark:text-zinc-400"
        >
          {if @action == :new,
            do: "Choose an action you can repeat.",
            else: "Adjust this habit's name or cadence."}
        </p>
      </header>

      <.form
        for={@form}
        id="habit-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        class="mt-7 space-y-5"
      >
        <.input
          field={@form[:name]}
          type="text"
          label="Habit"
          placeholder="Read before bed"
          autocomplete="off"
        />

        <div :if={@action == :edit} class="space-y-5">
          <.input
            field={@form[:identity]}
            type="text"
            label="Identity"
            placeholder="I am someone who..."
          />
          <.input
            field={@form[:why_it_matters]}
            type="textarea"
            label="Why it matters"
            placeholder="Why is this worth becoming consistent at?"
          />
          <.input
            field={@form[:what_counts]}
            type="textarea"
            label="What counts as progress"
            placeholder="Describe the smallest honest action that counts."
          />
        </div>

        <fieldset class="rounded-panel border border-zinc-200 bg-zinc-50/70 p-4 dark:border-zinc-800 dark:bg-zinc-950/70">
          <legend class="px-1 text-sm font-medium leading-5 text-zinc-900 dark:text-zinc-100">
            Cadence
          </legend>
          <div class={[
            "grid grid-cols-1 gap-3",
            if(@has_flexible_target,
              do: "sm:grid-cols-[9rem_9rem_1fr]",
              else: "sm:grid-cols-[9rem_1fr]"
            )
          ]}>
            <.input
              field={@form[:min_completions]}
              type="number"
              label={if @has_flexible_target, do: "Minimum", else: "Times"}
              max={31}
              min={1}
            />
            <.input
              :if={@has_flexible_target}
              field={@form[:max_completions]}
              type="number"
              label="Maximum"
              max={31}
              min={1}
            />
            <input
              :if={!@has_flexible_target}
              type="hidden"
              name="habit[max_completions]"
              value=""
            />
            <.input
              field={@form[:periodicity]}
              type="select"
              label="Per"
              options={[Day: :day, Week: :week, Month: :month]}
            />
          </div>
          <div class="mt-4">
            <label class="inline-flex cursor-pointer text-sm leading-6 text-muted">
              <input type="hidden" name="habit[has_flexible_target]" value="false" />
              <input
                id="habit-has-flexible-target"
                type="checkbox"
                name="habit[has_flexible_target]"
                value="true"
                checked={@has_flexible_target}
                class="peer sr-only"
              />
              <span class="hover:text-zinc-900 peer-checked:font-medium peer-checked:text-zinc-900 peer-focus-visible:rounded-sm peer-focus-visible:outline peer-focus-visible:outline-2 peer-focus-visible:outline-offset-2 peer-focus-visible:outline-focus dark:hover:text-zinc-100 dark:peer-checked:text-zinc-100">
                {if @has_flexible_target,
                  do: "Use a single target",
                  else: "Use a flexible range"}
              </span>
            </label>
          </div>
        </fieldset>

        <.button
          phx-disable-with="Saving..."
          class="w-full"
        >
          {if @action == :new, do: "Create habit", else: "Save changes"}
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
     |> assign(:has_flexible_target, not is_nil(habit.max_completions))
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"habit" => habit_params}, socket) do
    changeset =
      socket.assigns.habit
      |> Habits.change_habit(habit_params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:has_flexible_target, habit_params["has_flexible_target"] == "true")
     |> assign_form(changeset)}
  end

  def handle_event(
        "save",
        %{
          "habit" =>
            %{
              "has_flexible_target" => has_flexible_target,
              "max_completions" => max_completions
            } = habit_params
        },
        socket
      ) do
    has_flexible_target = has_flexible_target == "true"
    socket = assign(socket, :has_flexible_target, has_flexible_target)

    if has_flexible_target and max_completions == "" do
      changeset =
        socket.assigns.habit
        |> Habits.change_habit(habit_params)
        |> Ecto.Changeset.add_error(:max_completions, "can't be blank")
        |> Map.put(:action, :validate)

      {:noreply, assign_form(socket, changeset)}
    else
      save_habit(socket, socket.assigns.action, habit_params)
    end
  end

  defp save_habit(socket, :edit, habit_params) do
    case Habits.update_habit(get_current_user(socket), socket.assigns.habit.id, habit_params) do
      {:ok, habit} ->
        notify_parent({:saved, habit})

        {:noreply,
         socket
         |> put_flash(:info, "Habit updated.")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "Habit not found.")
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
         |> put_flash(:info, "Habit created.")
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
