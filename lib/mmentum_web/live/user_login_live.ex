defmodule MmentumWeb.UserLoginLive do
  use MmentumWeb, :live_view

  def render(assigns) do
    ~H"""
    <.auth_page>
      <.header class="text-center">
        Log in
        <:subtitle>
          New to Mmentum?
          <.text_link navigate={~p"/users/register"}>
            Create an account
          </.text_link>
        </:subtitle>
      </.header>

      <.simple_form for={@form} id="login_form" action={~p"/login"} phx-update="ignore">
        <.input field={@form[:email]} type="email" label="Email" required />
        <.input field={@form[:password]} type="password" label="Password" required />

        <:actions>
          <.input field={@form[:remember_me]} type="checkbox" label="Keep me logged in" />
          <.text_link href={~p"/users/reset_password"} class="text-sm">
            Forgot your password?
          </.text_link>
        </:actions>
        <:actions>
          <.button phx-disable-with="Logging in..." class="w-full">
            Log in <span aria-hidden="true">→</span>
          </.button>
        </:actions>
      </.simple_form>
    </.auth_page>
    """
  end

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")
    {:ok, assign(socket, form: form), temporary_assigns: [form: form]}
  end
end
