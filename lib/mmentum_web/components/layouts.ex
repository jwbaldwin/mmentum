defmodule MmentumWeb.Layouts do
  use MmentumWeb, :html

  @tau 2 * :math.pi()

  embed_templates "layouts/*"

  attr :id, :string, required: true
  attr :seed, :string, required: true
  attr :class, :string, default: nil

  def avatar(assigns) do
    assigns = assign(assigns, :model, avatar_model(assigns.seed))

    ~H"""
    <span
      id={@id}
      aria-hidden="true"
      style={@model.style}
      class={[
        "relative flex h-10 w-10 shrink-0 overflow-hidden rounded-full ring-1 ring-zinc-950/10",
        @class
      ]}
    >
      <svg
        viewBox="0 0 40 40"
        style="position: absolute; inset: 0; width: 100%; height: 100%;"
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
      style:
        "width: 2.5rem; min-width: 2.5rem; max-width: 2.5rem; height: 2.5rem; min-height: 2.5rem; max-height: 2.5rem; flex: 0 0 2.5rem; aspect-ratio: 1; border-radius: 9999px;",
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

      {x, y |> max(8) |> min(32) |> Float.round(2)}
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
