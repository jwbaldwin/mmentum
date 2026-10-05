defmodule MmentumWeb.Plugs.ReadOAuthConsent do
  @moduledoc false
  import Plug.Conn

  def init(options), do: options

  @doc "Restores the approved authorization request from the user's signed consent form"
  def call(%{params: %{"request" => signed_request, "decision" => decision}} = conn, _options)
      when decision in ["allow", "deny"] do
    consent = Application.fetch_env!(:mmentum, :oauth_consent)

    with {:ok, %{params: params, subject: subject, nonce: nonce}} <-
           Phoenix.Token.verify(conn, Keyword.fetch!(consent, :salt), signed_request,
             max_age: Keyword.fetch!(consent, :max_age)
           ),
         true <- subject == "user:#{conn.assigns.current_user.id}" do
      conn
      |> Map.put(:params, params)
      |> put_private(:oauth_consent_decision, {decision, nonce})
    else
      _ -> conn |> send_resp(400, "Invalid or expired consent request") |> halt()
    end
  end

  def call(conn, _options), do: conn |> send_resp(400, "Invalid consent decision") |> halt()
end
