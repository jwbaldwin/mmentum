defmodule MmentumWeb.Layouts do
  use MmentumWeb, :html

  @tau 2 * :math.pi()

  embed_templates "layouts/*"

  attr :current_user, :any, required: true

  def account_menu(assigns) do
    ~H"""
    <details
      id="account-menu"
      class="group relative"
      phx-click-away={JS.remove_attribute("open", to: "#account-menu")}
      phx-window-keydown={JS.remove_attribute("open", to: "#account-menu")}
      phx-key="escape"
    >
      <summary
        aria-label={"Account menu for #{@current_user.full_name}"}
        class="flex h-12 w-full px-2 py-1 min-w-0 cursor-pointer list-none select-none items-center justify-start gap-2 rounded-xl text-left text-zinc-900 transition-[background-color,box-shadow] duration-(--motion-duration-press) ease-(--motion-ease-out) hover:bg-zinc-100 hover:shadow-[inset_0_0_0_1px_rgb(24_24_27/0.06)] focus:outline-none focus-visible:shadow-[0_0_0_3px_color-mix(in_srgb,var(--color-focus)_24%,transparent),inset_0_0_0_1px_rgb(24_24_27/0.08)] group-open:bg-zinc-100 group-open:shadow-[inset_0_0_0_1px_rgb(24_24_27/0.06)] dark:text-zinc-100 dark:hover:bg-zinc-900 dark:hover:shadow-[inset_0_0_0_1px_rgb(255_255_255/0.08)] dark:focus-visible:shadow-[0_0_0_3px_color-mix(in_srgb,var(--color-focus)_24%,transparent),inset_0_0_0_1px_rgb(255_255_255/0.1)] dark:group-open:bg-zinc-900 dark:group-open:shadow-[inset_0_0_0_1px_rgb(255_255_255/0.08)] [&::-webkit-details-marker]:hidden"
      >
        <.avatar id="account-avatar" seed={@current_user.email} />
        <span class="min-w-0 flex-1">
          <span class="block truncate text-xs font-medium leading-4 text-zinc-900 dark:text-zinc-100">
            {@current_user.full_name}
          </span>
          <span class="block truncate text-[0.6875rem] font-normal leading-3.5 text-muted dark:text-zinc-400">
            {@current_user.email}
          </span>
        </span>
        <.icon
          name="hero-chevron-down-mini"
          class="h-3.5 w-3.5 flex-none text-muted transition-transform duration-[160ms] ease-[var(--motion-ease-out)] group-open:rotate-180 dark:text-zinc-400"
        />
      </summary>

      <div
        id="account-menu-popover"
        class="account-menu-popover absolute right-0 top-[calc(100%+0.5rem)] z-50 w-[min(14rem,calc(100vw-4rem))] origin-top-right overflow-hidden rounded-panel bg-white/[0.92] p-1.5 shadow-[0_14px_32px_rgb(24_24_27/0.12),0_3px_10px_rgb(24_24_27/0.06),inset_0_0_0_1px_rgb(24_24_27/0.08)] backdrop-blur-[20px] backdrop-saturate-[1.6] dark:bg-zinc-950/[0.92]"
      >
        <.account_menu_item navigate={~p"/users/settings"} icon="hero-user">
          Settings
        </.account_menu_item>
        <.appearance_toggle />
        <div class="mx-2 my-1 h-px bg-zinc-950/[0.07] dark:bg-zinc-50/[0.07]"></div>
        <.account_menu_item href={~p"/users/log_out"} method="delete" icon="hero-arrow-right-on-rectangle">
          Log out
        </.account_menu_item>
      </div>
    </details>
    """
  end

  defp appearance_toggle(assigns) do
    ~H"""
    <button
      id="account-appearance"
      phx-hook="ThemeToggle"
      type="button"
      data-theme-cycle
      data-roll-ready="false"
      aria-label="Appearance: Auto. Switch to Light"
      class="motion-press flex min-h-9 w-full items-center gap-2.5 rounded-control px-2.5 py-2 text-left text-zinc-700 transition-[background-color,color,scale] duration-[var(--motion-duration-press)] ease-[var(--motion-ease-out)] hover:bg-zinc-100 hover:text-zinc-900 focus-visible:bg-zinc-100 focus-visible:text-zinc-900 focus-visible:outline-none active:scale-[0.98] dark:text-zinc-300 dark:hover:bg-zinc-900 dark:hover:text-zinc-100 dark:focus-visible:bg-zinc-900 dark:focus-visible:text-zinc-100"
    >
      <svg
        data-appearance-icon
        data-theme="light"
        viewBox="0 0 24 24"
        class="appearance-morph h-4 w-4 flex-none overflow-visible text-muted dark:text-zinc-400"
        aria-hidden="true"
      >
        <path
          data-appearance-path
          fill="currentColor"
          d="M12 2.75 13.42 6.66 17.59 4.41 17.34 9.08 21.25 12 17.34 14.92 17.59 19.59 13.42 17.34 12 21.25 10.58 17.34 6.41 19.59 6.66 14.92 2.75 12 6.66 9.08 6.41 4.41 10.58 6.66Z"
        />
      </svg>
      <span class="text-[0.8125rem] font-medium leading-5">Appearance</span>
      <span data-appearance-roll class="appearance-roll ml-auto" aria-hidden="true">
        <span data-appearance-track class="appearance-roll-track">
          <span class="appearance-roll-face" style="--appearance-face: 0">Auto</span>
          <span class="appearance-roll-face" style="--appearance-face: 1">Light</span>
          <span class="appearance-roll-face" style="--appearance-face: 2">Dark</span>
        </span>
      </span>
      <span data-appearance-status class="sr-only">Auto, system Light</span>
    </button>
    """
  end

  attr :navigate, :string, default: nil
  attr :href, :string, default: nil
  attr :method, :string, default: nil
  attr :icon, :string, required: true
  slot :inner_block, required: true

  defp account_menu_item(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      href={@href}
      method={@method}
      class="flex min-h-9 items-center gap-2.5 rounded-control px-2.5 py-2 text-[0.8125rem] font-medium leading-5 text-zinc-700 transition-colors duration-[120ms] ease-[var(--motion-ease-out)] hover:bg-zinc-100 hover:text-zinc-900 focus-visible:bg-zinc-100 focus-visible:text-zinc-900 focus-visible:outline-none active:bg-zinc-200 dark:text-zinc-300 dark:hover:bg-zinc-900 dark:hover:text-zinc-100 dark:focus-visible:bg-zinc-900 dark:focus-visible:text-zinc-100 dark:active:bg-zinc-800"
    >
      <.icon name={@icon} class="h-4 w-4 flex-none text-muted dark:text-zinc-400" />
      <span>{render_slot(@inner_block)}</span>
    </.link>
    """
  end

  attr :id, :string, required: true
  attr :seed, :string, required: true
  attr :class, :string, default: nil

  def avatar(assigns) do
    assigns = assign(assigns, :model, avatar_model(assigns.seed))

    ~H"""
    <span
      id={@id}
      aria-hidden="true"
      class={[
        "block shrink-0 overflow-hidden rounded-full ring-1 ring-zinc-950/10 dark:ring-zinc-50/10",
        @class
      ]}
      style="width: 32px; height: 32px; min-width: 32px; min-height: 32px; max-width: 32px; max-height: 32px;"
    >
      <svg
        viewBox="0 0 40 40"
        width="32"
        height="32"
        class="block"
        style="width: 32px; height: 32px; max-width: 32px; max-height: 32px;"
      >
        <defs>
          <clipPath id={"#{@id}-clip"}>
            <circle cx="20" cy="20" r="20" />
          </clipPath>
          <linearGradient
            id={"#{@id}-top-gradient"}
            gradientUnits="userSpaceOnUse"
            x1={@model.top_gradient.x1}
            y1={@model.top_gradient.y1}
            x2={@model.top_gradient.x2}
            y2={@model.top_gradient.y2}
          >
            <stop offset="0%" stop-color={@model.top_gradient.start} />
            <stop offset="100%" stop-color={@model.top_gradient.end} />
          </linearGradient>
          <linearGradient
            id={"#{@id}-bottom-gradient"}
            gradientUnits="userSpaceOnUse"
            x1={@model.bottom_gradient.x1}
            y1={@model.bottom_gradient.y1}
            x2={@model.bottom_gradient.x2}
            y2={@model.bottom_gradient.y2}
          >
            <stop offset="0%" stop-color={@model.bottom_gradient.start} />
            <stop offset="100%" stop-color={@model.bottom_gradient.end} />
          </linearGradient>
        </defs>

        <g clip-path={"url(##{@id}-clip)"}>
          <path d={@model.top_path} fill={"url(##{@id}-top-gradient)"} />
          <path d={@model.bottom_path} fill={"url(##{@id}-bottom-gradient)"} />
          <path
            d={@model.boundary_path}
            fill="none"
            stroke="#71717a"
            stroke-width="0.45"
            opacity="0.42"
          />
        </g>
      </svg>
    </span>
    """
  end

  defp avatar_model(seed) do
    hash =
      seed
      |> String.trim()
      |> then(&if(&1 == "", do: "anonymous", else: &1))
      |> hash_avatar_seed()

    points = wave_points(hash)
    boundary_path = path_through(points)
    {_first_x, first_y} = List.first(points)
    {_last_x, last_y} = List.last(points)
    {top_colors, bottom_colors} = gradient_colors(hash)

    %{
      boundary_path: boundary_path,
      top_path:
        "M -2 -2 H 42 V #{last_y} " <>
          Enum.map_join(Enum.reverse(points), " ", fn {x, y} -> "L #{x} #{y}" end) <> " Z",
      bottom_path: boundary_path <> " L 42 42 H -2 V #{first_y} Z",
      top_gradient: Map.merge(gradient_vector(hash, 3), top_colors),
      bottom_gradient: Map.merge(gradient_vector(hash, 13), bottom_colors)
    }
  end

  defp wave_points(hash) do
    phase = rem(Bitwise.bsr(hash, 5), 628) / 100
    midpoint = 20 + rem(Bitwise.bsr(hash, 11), 5) - 2
    sine_amplitude = 3 + rem(Bitwise.bsr(hash, 16), 4)
    cosine_amplitude = 1 + rem(Bitwise.bsr(hash, 20), 3)
    tangent_amplitude = 0.5 + rem(Bitwise.bsr(hash, 23), 3) / 2
    sine_frequency = 0.8 + rem(Bitwise.bsr(hash, 9), 90) / 100
    cosine_frequency = 0.45 + rem(Bitwise.bsr(hash, 18), 70) / 100
    tangent_frequency = 0.35 + rem(Bitwise.bsr(hash, 25), 45) / 100

    for x <- -2..42 do
      progress = (x + 2) / 44

      tangent =
        progress
        |> Kernel.*(tangent_frequency * @tau)
        |> Kernel.+(phase * 1.3)
        |> :math.sin()
        |> Kernel.*(0.55)
        |> :math.tan()
        |> Kernel./(:math.tan(0.55))

      y =
        midpoint +
          sine_amplitude * :math.sin(progress * sine_frequency * @tau + phase) +
          cosine_amplitude * :math.cos(progress * cosine_frequency * @tau - phase * 0.6) +
          tangent_amplitude * tangent

      {x, y |> max(8.0) |> min(32.0) |> Float.round(2)}
    end
  end

  defp path_through([{x, y} | points]) do
    "M #{x} #{y} " <>
      Enum.map_join(points, " ", fn {next_x, next_y} -> "L #{next_x} #{next_y}" end)
  end

  defp gradient_vector(hash, shift) do
    left_to_right? = rem(Bitwise.bsr(hash, shift), 2) == 0
    tilt = rem(Bitwise.bsr(hash, shift + 1), 25) - 12

    %{
      x1: if(left_to_right?, do: 0, else: 40),
      y1: 20 - tilt,
      x2: if(left_to_right?, do: 40, else: 0),
      y2: 20 + tilt
    }
  end

  defp gradient_colors(hash) do
    light_gradients = [
      %{start: "#ffffff", end: "#d4d4d8"},
      %{start: "#fafafa", end: "#e4e4e7"},
      %{start: "#ffffff", end: "#c4c4c9"},
      %{start: "#f4f4f5", end: "#d4d4d8"}
    ]

    dark_gradients = [
      %{start: "#18181b", end: "#71717a"},
      %{start: "#27272a", end: "#a1a1aa"},
      %{start: "#18181b", end: "#52525b"},
      %{start: "#27272a", end: "#71717a"}
    ]

    light = Enum.at(light_gradients, rem(Bitwise.bsr(hash, 7), length(light_gradients)))
    dark = Enum.at(dark_gradients, rem(Bitwise.bsr(hash, 15), length(dark_gradients)))

    if rem(hash, 2) == 0, do: {light, dark}, else: {dark, light}
  end

  defp hash_avatar_seed(seed) do
    Enum.reduce(:binary.bin_to_list(seed), 2_166_136_261, fn byte, hash ->
      hash
      |> Bitwise.bxor(byte)
      |> Kernel.*(16_777_619)
      |> Bitwise.band(0xFFFFFFFF)
    end)
  end
end
