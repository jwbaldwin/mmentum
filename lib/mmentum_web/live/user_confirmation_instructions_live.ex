defmodule MmentumWeb.UserConfirmationInstructionsLive do
  use MmentumWeb, :live_view

  alias Mmentum.Accounts

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Resend confirmation email
        <:subtitle>We'll send a new confirmation link to your inbox</:subtitle>
      </.header>

      <.simple_form for={@form} id="resend_confirmation_form" phx-submit="send_instructions">
        <.input field={@form[:email]} type="email" label="Email" required />
        <:actions>
          <.button phx-disable-with="Sending..." class="w-full">
            Resend confirmation email
          </.button>
        </:actions>
      </.simple_form>

      <p class="mt-5 flex items-center justify-center gap-4 type-body">
        <.link href={~p"/users/register"} class="text-link">Create account</.link>
        <span aria-hidden="true" class="text-zinc-300 dark:text-zinc-700">/</span>
        <.link href={~p"/login"} class="text-link">Log in</.link>
      </p>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{}, as: "user"))}
  end

  def handle_event("send_instructions", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_confirmation_instructions(
        user,
        &url(~p"/users/confirm/#{&1}")
      )
    end

    info =
      "If an unconfirmed account matches that email, a new link is on its way."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> redirect(to: ~p"/login")}
  end
end
