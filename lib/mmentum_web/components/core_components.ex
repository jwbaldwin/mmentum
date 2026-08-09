defmodule MmentumWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At the first glance, this module may seem daunting, but its goal is
  to provide some core building blocks in your application, such as modals,
  tables, and forms. The components are mostly markup and well documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The default components use Tailwind CSS, a utility-first CSS framework.
  See the [Tailwind CSS documentation](https://tailwindcss.com) to learn
  how to customize them or feel free to swap in another framework altogether.

  Icons are provided by [heroicons](https://heroicons.com). See `icon/1` for usage
  """
  use Phoenix.Component
  use Gettext, backend: MmentumWeb.Gettext

  alias Phoenix.LiveView.JS

  @heroicons_path Path.expand("../../../assets/vendor/heroicons/optimized", __DIR__)
  @heroicons for {directory, suffix} <- [
                   {"24/outline", ""},
                   {"24/solid", "-solid"},
                   {"20/solid", "-mini"}
                 ],
                 file_path <- Path.wildcard(Path.join(@heroicons_path, "#{directory}/*.svg")),
                 icon_name = Path.basename(file_path, ".svg"),
                 into: %{},
                 do: {"hero-#{icon_name}#{suffix}", File.read!(file_path)}

  @doc """
  Renders a modal.

  ## Examples

      <.modal id="confirm-modal">
        This is a modal.
      </.modal>

  JS commands may be passed to the `:on_cancel` to configure
  the closing/cancel event, for example:

      <.modal id="confirm" on_cancel={JS.navigate(~p"/posts")}>
        This is another modal.
      </.modal>

  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :size, :string, default: "max-w-3xl"
  attr :on_cancel, JS, default: %JS{}
  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-50 hidden"
    >
      <div
        id={"#{@id}-bg"}
        class="motion-modal-backdrop fixed inset-0 bg-zinc-50/90 dark:bg-zinc-950/90"
        aria-hidden="true"
      />
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full items-center justify-center p-4 sm:p-6">
          <div class={["w-full", @size]}>
            <.focus_wrap
              id={"#{@id}-container"}
              phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
              phx-key="escape"
              phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
              class="motion-modal-panel relative hidden origin-center rounded-modal bg-white p-6 shadow-modal ring-1 ring-zinc-950/10 dark:bg-zinc-950 dark:shadow-[0_28px_72px_rgb(0_0_0/0.48),0_8px_24px_rgb(0_0_0/0.28)] dark:ring-zinc-50/10 sm:p-8"
            >
              <div class="absolute right-4 top-4 sm:right-5 sm:top-5">
                <button
                  phx-click={JS.exec("data-cancel", to: "##{@id}")}
                  type="button"
                  class="button-feedback flex h-9 w-9 items-center justify-center rounded-control text-zinc-400 hover:bg-zinc-100 hover:text-zinc-700 focus-visible:outline-none focus-visible:ring-3 focus-visible:ring-focus/20 focus-visible:ring-offset-2 dark:text-zinc-500 dark:hover:bg-zinc-900 dark:hover:text-zinc-300 dark:focus-visible:ring-offset-zinc-950"
                  aria-label={gettext("close")}
                >
                  <.icon name="hero-x-mark-solid" class="h-5 w-5" />
                </button>
              </div>
              <div id={"#{@id}-content"}>
                {render_slot(@inner_block)}
              </div>
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a simple form.

  ## Examples

      <.simple_form for={@form} phx-change="validate" phx-submit="save">
        <.input field={@form[:email]} label="Email"/>
        <.input field={@form[:username]} label="Username" />
        <:actions>
          <.button>Save</.button>
        </:actions>
      </.simple_form>
  """
  attr :for, :any, required: true, doc: "the datastructure for the form"
  attr :as, :any, default: nil, doc: "the server side parameter to collect all input under"
  attr :class, :any, default: "mt-8"

  attr :rest, :global,
    include: ~w(autocomplete name rel action enctype method novalidate target multipart),
    doc: "the arbitrary HTML attributes to apply to the form tag"

  slot :inner_block, required: true
  slot :actions, doc: "the slot for form actions, such as a submit button"

  def simple_form(assigns) do
    ~H"""
    <.form :let={f} for={@for} as={@as} class={@class} {@rest}>
      <div class="space-y-5">
        {render_slot(@inner_block, f)}
        <div :for={action <- @actions} class="flex items-center justify-between gap-4 pt-1">
          {render_slot(action, f)}
        </div>
      </div>
    </.form>
    """
  end

  @doc """
  Renders a button.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" class="ml-2">Send!</.button>
  """
  attr :type, :string, default: nil
  attr :variant, :string, default: "primary", values: ~w(primary destructive)
  attr :size, :string, default: "default", values: ~w(default compact)
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(disabled form name value)

  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "button-feedback inline-flex items-center justify-center gap-2 rounded-control type-label",
        "focus-visible:outline-none focus-visible:ring-3 focus-visible:ring-focus/25 focus-visible:ring-offset-2 dark:focus-visible:ring-offset-zinc-950",
        "disabled:cursor-not-allowed disabled:opacity-50 phx-submit-loading:cursor-wait phx-submit-loading:opacity-65",
        button_size(@size),
        button_variant(@variant),
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  defp button_variant("primary") do
    "bg-action text-white shadow-control hover:bg-action-hover active:text-white/80 dark:bg-zinc-100 dark:text-zinc-950 dark:shadow-[0_1px_2px_rgb(0_0_0/0.22)] dark:hover:bg-zinc-200 dark:active:text-zinc-950/80"
  end

  defp button_variant("destructive") do
    "text-danger hover:bg-danger-soft active:text-rose-800 dark:text-rose-400 dark:hover:bg-[#2e1016] dark:active:text-rose-300"
  end

  defp button_size("default"), do: "min-h-11 px-4 py-2.5"
  defp button_size("compact"), do: "min-h-9 px-2.5 py-1.5"

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any
  attr :class, :string, default: nil

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file hidden month number password
               range radio search select tel text textarea time url week)

  attr :field, Phoenix.HTML.FormField, doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"

  attr :rest, :global, include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  slot :inner_block

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(field.errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox", value: value} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn -> Phoenix.HTML.Form.normalize_value("checkbox", value) end)

    ~H"""
    <div phx-feedback-for={@name}>
      <label class="flex items-center gap-3 type-body text-zinc-600 dark:text-zinc-400">
        <input type="hidden" name={@name} value="false" />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class="h-4 w-4 rounded border-zinc-300 text-action shadow-control focus:ring-3 focus:ring-focus/20 disabled:cursor-not-allowed disabled:opacity-50 dark:border-zinc-700 dark:text-zinc-100 dark:shadow-[0_1px_2px_rgb(0_0_0/0.22)]"
          {@rest}
        />
        {@label}
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <.label :if={@label} for={@id}>{@label}</.label>
      <select
        id={@id}
        name={@name}
        class={field_classes(@errors, @class, "h-11 py-0 pr-9")}
        aria-invalid={to_string(@errors != [])}
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value="">{@prompt}</option>
        {Phoenix.HTML.Form.options_for_select(@options, @value)}
      </select>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <.label :if={@label} for={@id}>{@label}</.label>
      <textarea
        id={@id}
        name={@name}
        class={field_classes(@errors, @class, "min-h-28 resize-y py-3")}
        aria-invalid={to_string(@errors != [])}
        {@rest}
      ><%= Phoenix.HTML.Form.normalize_value("textarea", @value) %></textarea>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <.label :if={@label} for={@id}>{@label}</.label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={field_classes(@errors, @class, "h-11")}
        aria-invalid={to_string(@errors != [])}
        {@rest}
      />
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  defp field_classes(errors, class, sizing) do
    [
      "mt-2 block w-full rounded-control border bg-white px-3.5 text-base leading-6 text-zinc-900 shadow-control dark:bg-zinc-950 dark:text-zinc-100 dark:shadow-[0_1px_2px_rgb(0_0_0/0.22)] sm:text-sm sm:leading-5",
      "transition-[border-color,box-shadow,background-color] duration-[var(--motion-duration-press)] ease-[var(--motion-ease-out)]",
      "placeholder:text-zinc-400 focus:outline-none focus:ring-3 focus:ring-focus/20 disabled:cursor-not-allowed disabled:bg-zinc-100 disabled:text-muted dark:placeholder:text-zinc-500 dark:disabled:bg-zinc-900 dark:disabled:text-zinc-400",
      "phx-no-feedback:border-zinc-300 phx-no-feedback:focus:border-focus dark:phx-no-feedback:border-zinc-700",
      errors == [] && "border-zinc-300 focus:border-focus dark:border-zinc-700",
      errors != [] &&
        "border-danger focus:border-danger focus:ring-danger/15 dark:border-rose-400 dark:focus:border-rose-400 dark:focus:ring-rose-400/15",
      sizing,
      class
    ]
  end

  @doc """
  Renders a label
  """
  attr :for, :string, default: nil
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class="block type-label text-zinc-800 dark:text-zinc-200">
      {render_slot(@inner_block)}
    </label>
    """
  end

  @doc """
  Generates a generic error message
  """
  slot :inner_block, required: true

  def error(assigns) do
    ~H"""
    <p class="mt-2 flex items-center gap-2 text-xs font-medium leading-5 text-danger phx-no-feedback:hidden dark:text-rose-400">
      <.icon name="hero-exclamation-circle-mini" class="h-4 w-4 flex-none" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a header with title
  """
  attr :class, :string, default: nil
  attr :variant, :string, default: "default", values: ~w(default dashboard)

  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-start justify-between gap-4 sm:gap-6", @class]}>
      <div class="min-w-0">
        <h1 class={if(@variant == "dashboard", do: "type-display-title", else: "type-page-title")}>
          {render_slot(@inner_block)}
        </h1>
        <p
          :if={@subtitle != []}
          class={[
            "type-body text-muted dark:text-zinc-400",
            if(@variant == "dashboard", do: "mt-1 sm:text-base sm:leading-7", else: "mt-2")
          ]}
        >
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc "Renders a section title"
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def section_title(assigns) do
    ~H"""
    <h2 class={["type-section-title", @class]}>{render_slot(@inner_block)}</h2>
    """
  end

  @doc ~S"""
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id"><%= user.id %></:col>
        <:col :let={user} label="username"><%= user.username %></:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="overflow-y-auto px-4 sm:overflow-visible sm:px-0">
      <table class="w-[40rem] mt-11 sm:w-full">
        <thead class="text-left text-sm leading-6 text-zinc-500 dark:text-zinc-400">
          <tr>
            <th :for={col <- @col} class="p-0 pr-6 pb-4 font-normal">{col[:label]}</th>
            <th class="relative p-0 pb-4"><span class="sr-only">{gettext("Actions")}</span></th>
          </tr>
        </thead>
        <tbody
          id={@id}
          phx-update={match?(%Phoenix.LiveView.LiveStream{}, @rows) && "stream"}
          class="relative divide-y divide-zinc-100 border-t border-zinc-200 text-sm leading-6 text-zinc-700 dark:divide-zinc-900 dark:border-zinc-800 dark:text-zinc-300"
        >
          <tr :for={row <- @rows} id={@row_id && @row_id.(row)} class="group hover:bg-zinc-50 dark:hover:bg-zinc-950">
            <td
              :for={{col, i} <- Enum.with_index(@col)}
              phx-click={@row_click && @row_click.(row)}
              class={["relative p-0", @row_click && "hover:cursor-pointer"]}
            >
              <div class="block py-4 pr-6">
                <span class="absolute -inset-y-px right-0 -left-4 group-hover:bg-zinc-50 dark:group-hover:bg-zinc-950 sm:rounded-l-xl" />
                <span class={["relative", i == 0 && "font-semibold text-zinc-900 dark:text-zinc-100"]}>
                  {render_slot(col, @row_item.(row))}
                </span>
              </div>
            </td>
            <td :if={@action != []} class="relative w-14 p-0">
              <div class="relative whitespace-nowrap py-4 text-right text-sm font-medium">
                <span class="absolute -inset-y-px -right-4 left-0 group-hover:bg-zinc-50 dark:group-hover:bg-zinc-950 sm:rounded-r-xl" />
                <span
                  :for={action <- @action}
                  class="relative ml-4 font-semibold leading-6 text-zinc-900 hover:text-zinc-700 dark:text-zinc-100 dark:hover:text-zinc-300"
                >
                  {render_slot(action, @row_item.(row))}
                </span>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title"><%= @post.title %></:item>
        <:item title="Views"><%= @post.views %></:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <div class="mt-10">
      <dl class="-my-4 divide-y divide-zinc-100 dark:divide-zinc-900">
        <div :for={item <- @item} class="flex gap-4 py-4 type-body sm:gap-8">
          <dt class="w-1/3 flex-none text-muted dark:text-zinc-400 sm:w-1/4">{item.title}</dt>
          <dd class="text-zinc-800 dark:text-zinc-200">{render_slot(item)}</dd>
        </div>
      </dl>
    </div>
    """
  end

  @doc """
  Renders a back navigation link.

  ## Examples

      <.back navigate={~p"/posts"}>Back to posts</.back>
  """
  attr :navigate, :any, required: true
  slot :inner_block, required: true

  def back(assigns) do
    ~H"""
    <div class="mt-12">
      <.link
        navigate={@navigate}
        class="button-feedback inline-flex items-center gap-1.5 rounded-control type-label text-zinc-700 hover:text-zinc-950 focus-visible:outline-none focus-visible:ring-3 focus-visible:ring-focus/20 dark:text-zinc-300 dark:hover:text-zinc-50"
      >
        <.icon name="hero-arrow-left-solid" class="h-3 w-3" />
        {render_slot(@inner_block)}
      </.link>
    </div>
    """
  end

  @doc false
  def toast_group_class(assigns) do
    [
      "pointer-events-none fixed z-50 grid max-h-screen w-full p-4 sm:max-w-[26rem]",
      assigns[:corner] == :bottom_left && "bottom-0 left-0 items-end flex-col-reverse",
      assigns[:corner] == :bottom_right && "bottom-0 right-0 items-end flex-col-reverse",
      assigns[:corner] == :top_left && "left-0 top-0 items-start flex-col",
      assigns[:corner] == :top_right && "right-0 top-0 items-start flex-col"
    ]
  end

  @doc false
  def toast_class(assigns) do
    icon_class =
      case {assigns[:id], assigns[:kind]} do
        {"client-error", _kind} -> "mmentum-toast--warning"
        {_id, :success} -> "mmentum-toast--success"
        {_id, :warning} -> "mmentum-toast--warning"
        {_id, :error} -> "mmentum-toast--error"
        {_id, _kind} -> "mmentum-toast--info"
      end

    [
      "mmentum-toast group/toast pointer-events-auto relative col-start-1 col-end-1 row-start-1 row-end-2",
      "w-full max-w-[calc(100vw-2rem)] items-center justify-between overflow-hidden rounded-panel border border-zinc-200 bg-white p-4 pr-10 shadow-floating dark:border-zinc-800 dark:bg-zinc-950 dark:shadow-[0_10px_28px_rgb(0_0_0/0.32),0_2px_8px_rgb(0_0_0/0.2)]",
      "[@media(scripting:enabled)]:opacity-0 [@media(scripting:enabled){[data-phx-main]_&}]:opacity-100",
      if(assigns[:rest][:hidden] == true, do: "hidden", else: "flex"),
      icon_class
    ]
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from your `assets/vendor/heroicons` directory and rendered
  inline, avoiding runtime CSS generation for dynamic icon names.

  ## Examples

      <.icon name="hero-x-mark-solid" />
      <.icon name="hero-arrow-path" class="ml-1 w-3 h-3 animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: nil

  def icon(%{name: "hero-" <> _} = assigns) do
    assigns = assign(assigns, :svg, hero_icon(assigns.name))

    ~H"""
    <span class={["inline-block align-middle [&>svg]:h-full [&>svg]:w-full", @class || "h-5 w-5"]}>
      {Phoenix.HTML.raw(@svg)}
    </span>
    """
  end

  defp hero_icon("hero-" <> icon_name) do
    Map.fetch!(@heroicons, "hero-#{icon_name}")
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 200,
      transition:
        {"transition-[opacity,transform] ease-[var(--motion-ease-out)] duration-[var(--motion-duration-modal)]",
         "opacity-0 scale-[0.98]", "opacity-100 scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 140,
      transition:
        {"transition-[opacity,transform] ease-[var(--motion-ease-out)] duration-[var(--motion-duration-exit)]",
         "opacity-100 scale-100", "opacity-0 scale-[0.98]"}
    )
  end

  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      time: 200,
      transition:
        {"transition-opacity ease-[var(--motion-ease-out)] duration-[var(--motion-duration-modal)]", "opacity-0",
         "opacity-100"}
    )
    |> show("##{id}-container")
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-content")
  end

  def hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      time: 140,
      transition:
        {"transition-opacity ease-[var(--motion-ease-out)] duration-[var(--motion-duration-exit)]", "opacity-100",
         "opacity-0"}
    )
    |> hide("##{id}-container")
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end

  @doc """
  Translates an error message using gettext
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(MmentumWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(MmentumWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
