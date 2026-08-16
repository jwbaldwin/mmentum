defmodule MmentumWeb.HabitComponents do
  use MmentumWeb, :html

  alias Mmentum.Habits.Habit

  attr :habit, Habit, required: true

  def cadence(assigns) do
    ~H"""
    <%= if @habit.max_completions do %>
      {@habit.min_completions}–{@habit.max_completions} per {@habit.periodicity}
    <% else %>
      {@habit.min_completions} per {@habit.periodicity}
    <% end %>
    """
  end

  attr :habit, Habit, required: true
  attr :completed, :integer, required: true

  def habit_progress(assigns) do
    assigns =
      assign(assigns,
        completion_cap: Habit.completion_cap(assigns.habit),
        optional_steps: optional_steps(assigns.habit),
        completion_summary: completion_summary(assigns.habit, assigns.completed)
      )

    ~H"""
    <div
      id={"habit-#{@habit.id}-progress"}
      class="habit-progress"
      data-completed={@completed}
      role="progressbar"
      aria-label={"#{@habit.name} required completions"}
      aria-valuemin="0"
      aria-valuemax={@habit.min_completions}
      aria-valuenow={min(@completed, @habit.min_completions)}
      aria-valuetext={@completion_summary}
      style={progress_style(@completion_cap, @completed)}
    >
      <span class="habit-progress__shape" aria-hidden="true">
        <span :if={@completion_cap > 1} class="habit-progress__track"></span>
        <span
          :for={step <- 1..@completion_cap}
          id={"habit-#{@habit.id}-progress-step-#{step}"}
          class="habit-progress__step"
          data-kind={if step in @optional_steps, do: "optional", else: "required"}
          data-state={if(step <= @completed, do: "complete", else: "pending")}
        ></span>
      </span>
      <span
        class={[
          "habit-progress__fill",
          @completed > 0 && @completed < @completion_cap && "habit-progress__fill--partial"
        ]}
        aria-hidden="true"
      >
        <span class="habit-progress__fill-fluid">
          <span
            :for={_step <- 1..@completion_cap}
            class="habit-progress__fill-fluid-step"
          ></span>
        </span>
        <span class="habit-progress__fill-beads">
          <span :for={_step <- 1..@completion_cap} class="habit-progress__fill-step"></span>
        </span>
      </span>
      <span class="habit-progress__optional-masks" aria-hidden="true">
        <span
          :for={step <- 1..@completion_cap}
          class="habit-progress__optional-mask"
          data-kind={if step in @optional_steps, do: "optional", else: "required"}
          data-state={if(step <= @completed, do: "complete", else: "pending")}
        >
          <svg
            :if={step in @optional_steps && step > @completed}
            class="habit-progress__optional-ring"
            viewBox="0 0 32 32"
            aria-hidden="true"
          >
            <circle cx="16" cy="16" r="16" fill="var(--progress-surface)" />
            <path
              d="M2.48 12.38 A14 14 0 1 1 2.48 19.62"
              fill="none"
              stroke="var(--progress-optional)"
              stroke-width="1.5"
              stroke-linecap="round"
              stroke-dasharray="3.5 3.5"
            />
          </svg>
        </span>
      </span>
    </div>
    <span
      id={"habit-#{@habit.id}-progress-status"}
      class="sr-only"
      aria-live="polite"
      aria-atomic="true"
    >
      {@completion_summary}
    </span>
    """
  end

  attr :habit, Habit, required: true
  attr :completed, :integer, required: true

  def completion_controls(assigns) do
    assigns = assign(assigns, :completion_cap, Habit.completion_cap(assigns.habit))

    ~H"""
    <div class="flex shrink-0 items-center gap-1">
      <.completion_control
        habit={@habit}
        event="remove_log"
        label="Remove completion"
        icon="hero-backward-solid"
        id_suffix="remove-completion"
        disabled={@completed == 0}
      />
      <.completion_control
        habit={@habit}
        event="add_log"
        label="Record completion"
        icon="hero-forward-solid"
        id_suffix="record-completion"
        disabled={@completed >= @completion_cap}
      />
    </div>
    """
  end

  def habit_progress_filter(assigns) do
    ~H"""
    <svg aria-hidden="true" width="0" height="0" focusable="false" class="absolute">
      <defs>
        <filter id="habit-progress-fluid" x="-10%" y="-25%" width="120%" height="150%">
          <feGaussianBlur in="SourceGraphic" stdDeviation="4" result="blurred" />
          <feColorMatrix
            in="blurred"
            values="1 0 0 0 0
                    0 1 0 0 0
                    0 0 1 0 0
                    0 0 0 18 -7"
            result="fluid"
          />
          <feComposite in="SourceGraphic" in2="fluid" operator="over" />
        </filter>
      </defs>
    </svg>
    """
  end

  attr :habit, Habit, required: true
  attr :event, :string, required: true
  attr :label, :string, required: true
  attr :icon, :string, required: true
  attr :id_suffix, :string, required: true
  attr :disabled, :boolean, required: true

  defp completion_control(assigns) do
    ~H"""
    <.tooltip
      id={"habit-#{@habit.id}-#{@id_suffix}-tooltip"}
      content={@label}
      disabled={@disabled}
    >
      <button
        phx-click={@event}
        phx-value-id={@habit.id}
        type="button"
        class={[
          "motion-press flex h-12 w-12 items-center justify-center rounded-control text-zinc-700 transition-[color,background-color,border-color,box-shadow,scale] dark:text-zinc-300",
          "duration-[var(--motion-duration-press)] ease-[var(--motion-ease-out)] hover:text-zinc-900 enabled:active:scale-[0.98] focus-visible:outline-none focus-visible:ring-3 focus-visible:ring-focus/25",
          "phx-click-loading:pointer-events-none phx-click-loading:cursor-wait phx-click-loading:opacity-60",
          @disabled && "cursor-not-allowed disabled:text-zinc-200 dark:disabled:text-zinc-800"
        ]}
        disabled={@disabled}
        aria-label={"#{@label} for #{@habit.name}"}
      >
        <.icon name={@icon} class="h-6 w-6" />
      </button>
    </.tooltip>
    """
  end

  defp optional_steps(%Habit{max_completions: nil}), do: []

  defp optional_steps(%Habit{min_completions: minimum, max_completions: maximum}) do
    (minimum + 1)..maximum
  end

  defp completion_summary(%Habit{max_completions: nil, min_completions: target}, completed) do
    "#{completed} of #{target} completed"
  end

  defp completion_summary(
         %Habit{min_completions: minimum, max_completions: maximum},
         completed
       ) do
    required_completed = min(completed, minimum)
    optional_completed = max(completed - minimum, 0)
    optional_total = maximum - minimum
    required_text = "#{required_completed} of #{minimum} required completions"

    optional_text =
      case optional_total do
        1 -> "1 optional completion"
        count -> "#{count} optional completions"
      end

    cond do
      completed < minimum -> required_text
      optional_completed == 0 -> "#{required_text}; goal met; #{optional_text} available"
      true -> "#{required_text}; goal met; #{optional_completed} of #{optional_text} completed"
    end
  end

  defp progress_style(completion_cap, completed) do
    total_connections = max(completion_cap - 1, 1)
    completed_connections = min(max(completed - 1, 0), total_connections)
    remaining = if completed == 0, do: 1.0, else: 1 - completed_connections / total_connections
    fill_offset = if completed == 0, do: 0.0, else: remaining

    [
      "--progress-fill-right-percent: #{Float.round(remaining * 100, 4)}%",
      "--progress-fill-offset-narrow: #{Float.round(fill_offset * 28, 4)}px",
      "--progress-fill-offset-mobile: #{Float.round(fill_offset * 32, 4)}px",
      "--progress-fill-offset-desktop: #{Float.round(fill_offset * 44, 4)}px"
    ]
    |> Enum.join("; ")
  end
end
