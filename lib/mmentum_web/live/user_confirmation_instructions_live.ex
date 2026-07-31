defmodule MmentumWeb.UserConfirmationInstructionsLive do
  use MmentumWeb, :live_view

  alias Mmentum.Accounts

  def render(assigns) do
    ~H"""
    <.auth_page>
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

      <.auth_navigation registration_path={~p"/users/register"} login_path={~p"/login"} />
    </.auth_page>
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
