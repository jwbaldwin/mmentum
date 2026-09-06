defmodule MmentumWeb.OAuthControllerTest do
  use MmentumWeb.ConnCase, async: true

  import Ecto.Query

  alias Mmentum.OAuth
  alias Mmentum.OAuth.Connection
  alias Mmentum.OAuthFixtures
  alias Mmentum.Repo

  setup do
    %{user: Mmentum.AccountsFixtures.user_fixture()}
  end

  test "stores the authorization request while unauthenticated and returns after login", %{user: user} do
    {params, _verifier} = OAuthFixtures.authorization_params()

    redirected = get(OAuthFixtures.https_conn(), "https://localhost:4443/oauth/authorize", params)

    assert redirected.status == 302
    assert redirected_to(redirected) == ~p"/login"
    assert get_session(redirected, :user_return_to) == "/oauth/authorize?" <> URI.encode_query(params)

    logged_in =
      redirected
      |> recycle()
      |> init_test_session(user_return_to: get_session(redirected, :user_return_to))
      |> post("https://localhost:4443/login", %{
        "user" => %{
          "email" => user.email,
          "password" => Mmentum.AccountsFixtures.valid_user_password()
        }
      })

    assert redirected_to(logged_in) == get_session(redirected, :user_return_to)
  end

  test "exchanges a browser-approved consent grant for OAuth tokens", %{user: user} do
    {code, verifier} = OAuthFixtures.authorize(user)

    token_response = OAuthFixtures.exchange(code, verifier)
    tokens = json_response(token_response, 200)

    assert %{
             "access_token" => access_token,
             "refresh_token" => refresh_token,
             "token_type" => "Bearer",
             "scope" => "mmentum:read mmentum:write"
           } = tokens

    assert is_binary(access_token)
    assert is_binary(refresh_token)

    assert {:ok, claims} = Attesto.Token.verify(OAuth.token_config(), access_token)
    assert claims["sub"] == "user:#{user.id}"
    assert claims["aud"] == OAuth.config().audience

    connection = Repo.one!(from connection in Connection, where: connection.user_id == ^user.id)
    assert connection.id == claims["mmentum_grant_id"]
    assert connection.client_id == "oauth-test"
    assert connection.refresh_family_id != nil
    assert connection.refresh_family_id != connection.id
    assert connection.scopes == ["mmentum:read", "mmentum:write"]
  end

  test "rejects consent posts without CSRF", %{user: user} do
    {params, _verifier} = OAuthFixtures.authorization_params()
    {conn, fields} = OAuthFixtures.consent_form(log_in_user(OAuthFixtures.https_conn(), user), params)
    fields = fields |> Map.delete("_csrf_token") |> Map.put("decision", "allow")

    assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
      post(OAuthFixtures.browser_recycle(conn), "https://localhost:4443/oauth/consent", fields)
    end
  end

  test "denies consent without minting an authorization code", %{user: user} do
    {params, _verifier} = OAuthFixtures.authorization_params()
    {conn, fields} = OAuthFixtures.consent_form(log_in_user(OAuthFixtures.https_conn(), user), params)

    denied = OAuthFixtures.decide_consent(conn, fields, "deny")

    assert denied.status == 302
    query = denied |> redirected_to() |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()
    assert query["error"] == "access_denied"
    refute Map.has_key?(query, "code")
  end

  test "rejects tampered consent requests", %{user: user} do
    {params, _verifier} = OAuthFixtures.authorization_params()
    {conn, fields} = OAuthFixtures.consent_form(log_in_user(OAuthFixtures.https_conn(), user), params)

    tampered = OAuthFixtures.decide_consent(conn, Map.update!(fields, "request", &(&1 <> "x")), "allow")

    assert tampered.status == 400
    assert tampered.resp_body == "Invalid or expired consent request"
  end

  test "does not replay an approved consent grant", %{user: user} do
    {params, _verifier} = OAuthFixtures.authorization_params()
    {conn, fields} = OAuthFixtures.consent_form(log_in_user(OAuthFixtures.https_conn(), user), params)

    approved = OAuthFixtures.decide_consent(conn, fields, "allow")
    assert approved.status == 302

    assert approved
           |> redirected_to()
           |> URI.parse()
           |> Map.fetch!(:query)
           |> URI.decode_query()
           |> Map.has_key?("code")

    replayed = OAuthFixtures.decide_consent(conn, fields, "allow")
    assert replayed.status == 302
    query = replayed |> redirected_to() |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()
    assert query["error"] == "access_denied"
    refute Map.has_key?(query, "code")
  end

  test "rejects authorization code exchange with a mismatched PKCE verifier", %{user: user} do
    {code, _verifier} = OAuthFixtures.authorize(user)

    mismatched_verifier = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
    exchanged = OAuthFixtures.exchange(code, mismatched_verifier)

    assert %{"error" => "invalid_grant"} = json_response(exchanged, 400)
  end

  test "owner disconnect before code redemption prevents token issuance", %{user: user} do
    {code, verifier} = OAuthFixtures.authorize(user)
    connection = Repo.one!(from connection in Connection, where: connection.user_id == ^user.id)

    disconnected =
      OAuthFixtures.https_conn()
      |> log_in_user(user)
      |> delete(~p"/users/connections/#{connection.id}")

    assert redirected_to(disconnected) == ~p"/users/connections"

    exchanged = OAuthFixtures.exchange(code, verifier)
    assert %{"error" => error} = json_response(exchanged, 400)
    assert error in ["invalid_grant", "invalid_request"]

    connection = Repo.get!(Connection, connection.id)
    assert connection.revoked_at
    assert connection.refresh_family_id == nil
  end

  test "refresh tokens rotate on use", %{user: user} do
    tokens = OAuthFixtures.tokens(user)

    refreshed = tokens["refresh_token"] |> OAuthFixtures.refresh() |> json_response(200)

    assert refreshed["access_token"] != tokens["access_token"]
    assert refreshed["refresh_token"] != tokens["refresh_token"]
    assert refreshed["token_type"] == "Bearer"
    assert refreshed["scope"] == "mmentum:read mmentum:write"

    reused = OAuthFixtures.refresh(tokens["refresh_token"])
    assert %{"error" => "invalid_grant"} = json_response(reused, 400)
  end

  test "MCP rejects invalid bearer tokens" do
    conn = send_mcp(OAuthFixtures.bearer_conn("not-a-jwt"))

    assert conn.status == 401
    assert get_resp_header(conn, "www-authenticate") != []
  end

  test "deleting a user invalidates their access and refresh tokens", %{user: user} do
    tokens = OAuthFixtures.tokens(user)
    Repo.delete!(user)

    assert send_mcp(OAuthFixtures.bearer_conn(tokens["access_token"])).status == 401

    assert %{"error" => "invalid_request"} =
             tokens["refresh_token"] |> OAuthFixtures.refresh() |> json_response(400)
  end

  test "MCP rejects expired bearer tokens", %{user: user} do
    tokens = OAuthFixtures.tokens(user)
    assert send_mcp(OAuthFixtures.bearer_conn(tokens["access_token"])).status == 200

    token = mint_bearer(tokens["access_token"], now: System.system_time(:second) - 3_600, lifetime: 1)

    assert send_mcp(OAuthFixtures.bearer_conn(token)).status == 401
    assert {:error, :expired} = Attesto.Token.verify(OAuth.token_config(), token)
  end

  test "MCP rejects bearer tokens for the wrong audience", %{user: user} do
    tokens = OAuthFixtures.tokens(user)
    assert send_mcp(OAuthFixtures.bearer_conn(tokens["access_token"])).status == 200

    token = mint_bearer(tokens["access_token"], audience: "https://localhost:4443/other")

    assert send_mcp(OAuthFixtures.bearer_conn(token)).status == 401
  end

  test "MCP accepts read-scoped bearer tokens", %{user: user} do
    tokens = OAuthFixtures.tokens(user, %{"scope" => "mmentum:read"})

    assert send_mcp(OAuthFixtures.bearer_conn(tokens["access_token"])).status == 200
  end

  test "MCP rejects write-only bearer tokens for read operations", %{user: user} do
    tokens = OAuthFixtures.tokens(user, %{"scope" => "mmentum:write"})
    assert send_mcp(OAuthFixtures.bearer_conn(tokens["access_token"])).status == 403
  end

  test "disconnect is user-owned and revokes existing access and descendant refresh tokens", %{user: user} do
    tokens = OAuthFixtures.tokens(user)
    refreshed = tokens["refresh_token"] |> OAuthFixtures.refresh() |> json_response(200)
    connection = Repo.one!(from connection in Connection, where: connection.user_id == ^user.id)

    other_user = Mmentum.AccountsFixtures.user_fixture()

    rejected_disconnect =
      OAuthFixtures.https_conn()
      |> log_in_user(other_user)
      |> delete(~p"/users/connections/#{connection.id}")

    assert rejected_disconnect.status == 404
    assert send_mcp(OAuthFixtures.bearer_conn(tokens["access_token"])).status == 200
    assert send_mcp(OAuthFixtures.bearer_conn(refreshed["access_token"])).status == 200

    disconnected =
      OAuthFixtures.https_conn()
      |> log_in_user(user)
      |> delete(~p"/users/connections/#{connection.id}")

    assert redirected_to(disconnected) == ~p"/users/connections"

    assert send_mcp(OAuthFixtures.bearer_conn(tokens["access_token"])).status == 401
    assert send_mcp(OAuthFixtures.bearer_conn(refreshed["access_token"])).status == 401

    refresh_after_disconnect = OAuthFixtures.refresh(refreshed["refresh_token"])
    assert %{"error" => "invalid_grant"} = json_response(refresh_after_disconnect, 400)
  end

  defp mint_bearer(access_token, opts) do
    {:ok, claims} = Attesto.Token.verify(OAuth.token_config(), access_token)

    {:ok, token} =
      Attesto.Token.mint(
        OAuth.token_config(),
        %{
          kind: "user",
          sub: Map.fetch!(claims, "sub"),
          scopes: String.split(Map.fetch!(claims, "scope")),
          claims: Map.take(claims, ["client_id", "mmentum_grant_id"])
        },
        opts
      )

    token.access_token
  end

  defp send_mcp(conn) do
    request = %{
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "server/discover",
      "params" => %{
        "_meta" => %{
          "io.modelcontextprotocol/protocolVersion" => "2026-07-28",
          "io.modelcontextprotocol/clientInfo" => %{"name" => "mmentum-test", "version" => "1.0.0"},
          "io.modelcontextprotocol/clientCapabilities" => %{}
        }
      }
    }

    conn
    |> put_req_header("content-type", "application/json")
    |> put_req_header("accept", "application/json, text/event-stream")
    |> put_req_header("mcp-protocol-version", "2026-07-28")
    |> put_req_header("mcp-method", "server/discover")
    |> post("https://localhost:4443/mcp", Jason.encode!(request))
  end
end
