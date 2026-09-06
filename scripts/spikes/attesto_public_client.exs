# Run with: elixir scripts/spikes/attesto_public_client.exs
# This standalone check deliberately fails until public-client revocation works.
# It does not start Mmentum, touch its database, or change its dependencies.
Mix.install([
  {:attesto_phoenix, "== 3.2.1"},
  {:attesto_mcp, "== 1.3.0"},
  {:attesto, "== 2.0.1"},
  {:jason, "~> 1.4"}
])

Logger.configure(level: :warning)
ExUnit.start()

defmodule AttestoPublicClientCheck do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Plug.Test

  alias AttestoPhoenix.Config
  alias AttestoPhoenix.Controller.{RevocationController, TokenController}

  setup do
    start_supervised!(Attesto.CodeStore.ETS)
    start_supervised!(Attesto.RefreshStore.ETS)

    private_key = :public_key.generate_key({:namedCurve, :secp256r1})
    signing_pem = :public_key.pem_encode([:public_key.pem_entry_encode(:ECPrivateKey, private_key)])
    Application.put_env(:attesto, Attesto.Keystore.Static, signing_pem: signing_pem)

    client = %{id: "public-mcp-client"}

    config =
      Config.new(
        issuer: "https://mmentum.example",
        audience: "https://mmentum.example/mcp",
        keystore: Attesto.Keystore.Static,
        # Config requires a repo module; the selected ETS stores never call it.
        repo: Ecto.Repo,
        principal_kinds: [Attesto.PrincipalKind.new("user", "user:")],
        load_client: fn
          "public-mcp-client" -> {:ok, client}
          _ -> {:error, :not_found}
        end,
        verify_client_secret: fn _, _ -> false end,
        client_id: fn client -> client.id end,
        client_public?: fn _ -> true end,
        client_redirect_uris: fn _ -> ["https://client.example/callback"] end,
        client_grant_types: fn _ -> ["authorization_code", "refresh_token"] end,
        load_principal: fn subject -> {:ok, %{subject: subject}} end,
        build_principal: fn _, subject, scopes -> %{sub: subject, kind: "user", scopes: scopes} end,
        grant_types_supported: ["authorization_code", "refresh_token"],
        token_endpoint_auth_methods_supported: ["none"],
        scopes_supported: ["mmentum:read", "mmentum:write"],
        authorize_scope: fn _, requested ->
          if Enum.all?(requested, &(&1 in ["mmentum:read", "mmentum:write"])) do
            {:ok, requested}
          else
            {:error, :invalid_scope}
          end
        end,
        resource_indicators: [allowed_resources: ["https://mmentum.example/mcp"]],
        code_store: Attesto.CodeStore.ETS,
        refresh_store: Attesto.RefreshStore.ETS,
        issue_refresh_token?: fn _, _ -> true end,
        dpop_enabled: false
      )

    %{config: config}
  end

  test "a public PKCE client can exchange and refresh tokens, then revoke its refresh token", %{config: config} do
    verifier = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
    {:ok, challenge} = Attesto.PKCE.challenge(verifier)

    {:ok, code} =
      Attesto.AuthorizationCode.issue(Attesto.CodeStore.ETS, %{
        client_id: "public-mcp-client",
        redirect_uri: "https://client.example/callback",
        subject: "user:1",
        scope: ["mmentum:read"],
        resource: ["https://mmentum.example/mcp"],
        family_id: "public-client-check",
        code_challenge: challenge,
        code_challenge_method: "S256"
      })

    issued =
      post(config, TokenController, "/oauth/token", %{
        "grant_type" => "authorization_code",
        "client_id" => "public-mcp-client",
        "redirect_uri" => "https://client.example/callback",
        "resource" => "https://mmentum.example/mcp",
        "code" => code,
        "code_verifier" => verifier
      })

    assert issued.status == 200, issued.resp_body
    tokens = Jason.decode!(issued.resp_body)
    assert is_binary(tokens["access_token"])
    assert is_binary(tokens["refresh_token"])
    IO.puts("PASS: public client exchanges its PKCE-bound code")

    protection =
      AttestoMCP.Plug.ProtectResource.prepare(
        config: Config.to_attesto_config(config),
        resource: "/mcp",
        base_url: "https://mmentum.example",
        resource_audience: :resource
      )

    authenticated =
      conn(:post, "https://mmentum.example/mcp")
      |> put_req_header("authorization", "Bearer " <> tokens["access_token"])
      |> AttestoMCP.Plug.ProtectResource.authenticate(protection)

    refute authenticated.halted
    assert authenticated.assigns.attesto_context.subject == "user:1"
    read_allowed = AttestoMCP.Plug.ProtectResource.authorize(authenticated, protection, ["mmentum:read"])
    refute read_allowed.halted
    write_denied = AttestoMCP.Plug.ProtectResource.authorize(authenticated, protection, ["mmentum:write"])
    assert write_denied.status == 403
    assert Jason.decode!(write_denied.resp_body)["error"] == "insufficient_scope"
    IO.puts("PASS: attesto_mcp accepts the token for reads and rejects writes")

    refreshed =
      post(config, TokenController, "/oauth/token", %{
        "grant_type" => "refresh_token",
        "client_id" => "public-mcp-client",
        "resource" => "https://mmentum.example/mcp",
        "refresh_token" => tokens["refresh_token"]
      })

    assert refreshed.status == 200, refreshed.resp_body
    rotated = Jason.decode!(refreshed.resp_body)
    assert rotated["refresh_token"] != tokens["refresh_token"]
    IO.puts("PASS: public client refreshes and rotates its refresh token")

    revoked =
      post(config, RevocationController, "/oauth/revoke", %{
        "client_id" => "public-mcp-client",
        "token" => rotated["refresh_token"],
        "token_type_hint" => "refresh_token"
      })

    IO.puts("Revocation response: HTTP #{revoked.status} #{revoked.resp_body}")

    after_revocation =
      post(config, TokenController, "/oauth/token", %{
        "grant_type" => "refresh_token",
        "client_id" => "public-mcp-client",
        "resource" => "https://mmentum.example/mcp",
        "refresh_token" => rotated["refresh_token"]
      })

    IO.puts("Refresh after attempted revocation: HTTP #{after_revocation.status}")
    assert revoked.status == 200
    assert after_revocation.status == 400
  end

  defp post(config, controller, path, params) do
    :post
    |> conn("https://mmentum.example" <> path, URI.encode_query(params))
    |> put_req_header("content-type", "application/x-www-form-urlencoded")
    |> Plug.Parsers.call(Plug.Parsers.init(parsers: [:urlencoded]))
    |> put_private(:attesto_phoenix_config, config)
    |> put_private(:attesto_protocol_config, Config.to_attesto_config(config))
    |> controller.call(controller.init(:create))
  end
end
