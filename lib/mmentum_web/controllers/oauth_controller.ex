defmodule MmentumWeb.OAuthController do
  use MmentumWeb, :controller

  alias AttestoPhoenix.Config
  alias AttestoPhoenix.ConsentGrant
  alias AttestoPhoenix.Store.EctoConsentGrantStore
  alias Mmentum.OAuth

  def authenticate_resource_owner(conn, _request, _options) do
    {:authenticated, %{subject: "user:#{conn.assigns.current_user.id}"}}
  end

  def consent(conn, request, subject) do
    with {:ok, _scopes} <- OAuth.authorize_scope(nil, request.scope),
         true <- request.resource in [[], [OAuth.config().audience]] do
      binding = ConsentGrant.binding(request, subject.subject)

      case conn.private[:oauth_consent_decision] do
        {decision, nonce} ->
          confirm_consent(decision, nonce, binding, subject)

        nil ->
          consent = Application.fetch_env!(:mmentum, :oauth_consent)
          {:ok, nonce} = EctoConsentGrantStore.mint(binding, Keyword.fetch!(consent, :max_age))

          signed_request =
            Phoenix.Token.sign(conn, Keyword.fetch!(consent, :salt), %{
              params: conn.params,
              subject: subject.subject,
              nonce: nonce
            })

          {:ok, client} = OAuth.load_client(request.client_id)

          {:halt,
           conn
           |> allow_consent_redirect(request.redirect_uri)
           |> put_resp_header("cache-control", "no-store")
           |> put_resp_header("referrer-policy", "no-referrer")
           |> put_view(html: MmentumWeb.OAuthHTML)
           |> render(:consent,
             client: client,
             scopes: request.scope,
             audience: OAuth.config().audience,
             form: Phoenix.Component.to_form(%{"request" => signed_request})
           )}
      end
    else
      _ -> {:denied, :invalid_scope_or_resource}
    end
  end

  defp confirm_consent(decision, nonce, binding, subject) do
    case EctoConsentGrantStore.consume(nonce, binding) do
      :ok when decision == "allow" -> {:consented, subject}
      _ -> {:denied, :access_denied}
    end
  end

  defp allow_consent_redirect(conn, redirect_uri) do
    callback = URI.parse(redirect_uri)
    origin = URI.to_string(%{callback | path: nil, query: nil, fragment: nil, userinfo: nil})
    [policy] = get_resp_header(conn, "content-security-policy")
    policy = String.replace(policy, "form-action 'self';", "form-action 'self' #{origin};")
    put_resp_header(conn, "content-security-policy", policy)
  end

  def connections(conn, _params) do
    render(conn, :connections, connections: OAuth.list_connections(conn.assigns.current_user))
  end

  def disconnect(conn, %{"id" => id}) do
    case OAuth.disconnect(conn.assigns.current_user, id) do
      {:ok, :ok} -> redirect(conn, to: ~p"/users/connections")
      {:error, :not_found} -> conn |> put_status(:not_found) |> text("Connection not found")
    end
  end

  # The bundled discovery controller also advertises PAR/introspection/JARM.
  # Compose only the capabilities and routes this host actually exposes.
  def discovery(conn, _params) do
    config = OAuth.config()

    metadata =
      config
      |> Config.to_attesto_config()
      |> Attesto.Discovery.metadata(
        authorization_endpoint: Config.authorize_endpoint_url(config),
        scopes_supported: config.scopes_supported,
        response_types_supported: ["code"],
        response_modes_supported: ["query"],
        grant_types_supported: Config.grant_types_supported(config),
        token_endpoint_auth_methods_supported: Config.token_endpoint_auth_methods_supported(config),
        authorization_response_iss_parameter_supported: true
      )
      |> Map.delete("dpop_signing_alg_values_supported")

    conn |> put_resp_header("cache-control", "public, max-age=300") |> json(metadata)
  end

  def resource_metadata(conn, _params) do
    config = OAuth.config()

    metadata =
      [resource: config.audience, authorization_servers: [config.issuer], scopes_supported: config.scopes_supported]
      |> AttestoMCP.Metadata.protected_resource()
      |> Map.delete("dpop_signing_alg_values_supported")

    conn |> put_resp_header("cache-control", "public, max-age=300") |> json(metadata)
  end
end
