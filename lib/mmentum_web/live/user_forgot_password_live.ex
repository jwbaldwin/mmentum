defmodule MmentumWeb.UserForgotPasswordLive do
  use MmentumWeb, :live_view

  alias Mmentum.Accounts

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Forgot your password?
        <:subtitle>We'll send a reset link to your inbox</:subtitle>
      </.header>

      <.simple_form for={@form} id="reset_password_form" phx-submit="send_email">
        <.input field={@form[:email]} type="email" label="Email" required />
        <:actions>
          <.button phx-disable-with="Sending..." class="w-full">
            Send reset link
          </.button>
        </:actions>
      </.simple_form>
      <p class="mt-5 flex items-center justify-center gap-4 type-body">
        <.link href={~p"/users/register"} class="text-link">Create account</.link>
        <span aria-hidden="true" class="text-zinc-300">/</span>
        <.link href={~p"/login"} class="text-link">Log in</.link>
      </p>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{}, as: "user"))}
  end

  def handle_event("send_email", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_reset_password_instructions(
        user,
        &url(~p"/users/reset_password/#{&1}")
      )
    end

    info =
      "If an account matches that email, a reset link is on its way."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> redirect(to: ~p"/login")}
  end
end
