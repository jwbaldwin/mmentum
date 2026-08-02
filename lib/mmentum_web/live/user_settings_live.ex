defmodule MmentumWeb.UserSettingsLive do
  use MmentumWeb, :live_view

  alias Mmentum.Accounts

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-2xl">
      <.header>
        Account settings
        <:subtitle>Manage your time zone, email, and password</:subtitle>
      </.header>

      <div class="mt-10 divide-y divide-zinc-200 dark:divide-zinc-800">
        <section class="pb-8">
          <.section_title>Time zone</.section_title>
          <p class="mt-1 text-sm font-normal leading-6 text-muted dark:text-zinc-400">
            Used to place completions on the correct day
          </p>
          <.simple_form
            for={@time_zone_form}
            id="time_zone_form"
            phx-submit="update_time_zone"
            class="mt-5 max-w-xl"
          >
            <.input
              field={@time_zone_form[:time_zone]}
              type="text"
              label="Time zone"
              placeholder="America/New_York"
            />
            <:actions>
              <.button phx-disable-with="Saving...">Save time zone</.button>
            </:actions>
          </.simple_form>
        </section>
        <section class="py-8">
          <.section_title>Email address</.section_title>
          <p class="mt-1 text-sm font-normal leading-6 text-muted dark:text-zinc-400">
            Change the address you use to log in
          </p>
          <.simple_form
            for={@email_form}
            id="email_form"
            phx-submit="update_email"
            phx-change="validate_email"
            class="mt-5 max-w-xl"
          >
            <.input field={@email_form[:email]} type="email" label="Email" required />
            <.input
              field={@email_form[:current_password]}
              name="current_password"
              id="current_password_for_email"
              type="password"
              label="Current password"
              value={@email_form_current_password}
              required
            />
            <:actions>
              <.button phx-disable-with="Changing...">Change email</.button>
            </:actions>
          </.simple_form>
        </section>
        <section class="pt-8">
          <.section_title>Password</.section_title>
          <p class="mt-1 text-sm font-normal leading-6 text-muted dark:text-zinc-400">
            Use at least 12 characters
          </p>
          <.simple_form
            for={@password_form}
            id="password_form"
            action={~p"/login?_action=password_updated"}
            method="post"
            phx-change="validate_password"
            phx-submit="update_password"
            phx-trigger-action={@trigger_submit}
            class="mt-5 max-w-xl"
          >
            <.input
              field={@password_form[:email]}
              type="hidden"
              id="hidden_user_email"
              value={@current_email}
            />
            <.input field={@password_form[:password]} type="password" label="New password" required />
            <.input
              field={@password_form[:password_confirmation]}
              type="password"
              label="Confirm new password"
            />
            <.input
              field={@password_form[:current_password]}
              name="current_password"
              type="password"
              label="Current password"
              id="current_password_for_password"
              value={@current_password}
              required
            />
            <:actions>
              <.button phx-disable-with="Changing...">Change password</.button>
            </:actions>
          </.simple_form>
        </section>
      </div>
    </div>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_user, token) do
        :ok ->
          put_flash(socket, :info, "Email changed.")

        :error ->
          put_flash(socket, :error, "This email change link is invalid or has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    email_changeset = Accounts.change_user_email(user)
    password_changeset = Accounts.change_user_password(user)
    time_zone_form = to_form(%{"time_zone" => user.time_zone}, as: :user)

    socket =
      socket
      |> assign(:current_password, nil)
      |> assign(:email_form_current_password, nil)
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:time_zone_form, time_zone_form)
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  def handle_event("update_time_zone", %{"user" => %{"time_zone" => time_zone}}, socket) do
    {:ok, user} = Accounts.update_user_time_zone(socket.assigns.current_user, time_zone)

    {:noreply,
     socket
     |> assign(:current_user, user)
     |> assign(:time_zone_form, to_form(%{"time_zone" => time_zone}, as: :user))
     |> put_flash(:info, "Time zone updated.")}
  end

  def handle_event("validate_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    email_form =
      socket.assigns.current_user
      |> Accounts.change_user_email(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form, email_form_current_password: password)}
  end

  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.apply_user_email(user, password, user_params) do
      {:ok, applied_user} ->
        Accounts.deliver_user_update_email_instructions(
          applied_user,
          user.email,
          &url(~p"/users/settings/confirm_email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info) |> assign(email_form_current_password: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :email_form, to_form(Map.put(changeset, :action, :insert)))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    password_form =
      socket.assigns.current_user
      |> Accounts.change_user_password(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form, current_password: password)}
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.update_user_password(user, password, user_params) do
      {:ok, user} ->
        password_form =
          user
          |> Accounts.change_user_password(user_params)
          |> to_form()

        {:noreply, assign(socket, trigger_submit: true, password_form: password_form)}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end
end
