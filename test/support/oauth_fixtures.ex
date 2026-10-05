defmodule Mmentum.OAuthFixtures do
  @moduledoc false
  import ExUnit.Assertions
  import Phoenix.ConnTest
  import Plug.Conn

  alias MmentumWeb.Endpoint

  @endpoint Endpoint

  def https_conn do
    %{build_conn() | scheme: :https, host: "localhost", port: 4443}
  end

  def browser_recycle(conn) do
    conn |> recycle() |> put_private(:plug_skip_csrf_protection, false)
  end

  def authorization_params(overrides \\ %{}) do
    verifier = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
    {:ok, challenge} = Attesto.PKCE.challenge(verifier)

    params = %{
      "response_type" => "code",
      "client_id" => "oauth-test",
      "redirect_uri" => "https://client.example/callback",
      "state" => "opaque-state",
      "scope" => "mmentum:read mmentum:write",
      "resource" => Mmentum.OAuth.config().audience,
      "code_challenge" => challenge,
      "code_challenge_method" => "S256"
    }

    {Map.merge(params, overrides), verifier}
  end

  def consent_form(conn, params) do
    conn = get(conn, "https://localhost:4443/oauth/authorize", params)
    assert conn.status == 200, conn.resp_body
    form = conn.resp_body |> Floki.parse_document!() |> Floki.find("#oauth-consent")

    fields =
      Map.new(Floki.find(form, "input"), fn input ->
        {[name], [value]} = {Floki.attribute(input, "name"), Floki.attribute(input, "value")}
        {name, value}
      end)

    {conn, fields}
  end

  def decide_consent(conn, fields, decision) do
    post(browser_recycle(conn), "https://localhost:4443/oauth/consent", Map.put(fields, "decision", decision))
  end

  def authorize(user, overrides \\ %{}) do
    {params, verifier} = authorization_params(overrides)
    {conn, fields} = consent_form(MmentumWeb.ConnCase.log_in_user(https_conn(), user), params)
    approved = decide_consent(conn, fields, "allow")
    assert approved.status == 302
    code = approved |> redirected_to() |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query() |> Map.fetch!("code")
    {code, verifier}
  end

  def exchange(code, verifier, overrides \\ %{}) do
    token_request(
      Map.merge(
        %{
          "grant_type" => "authorization_code",
          "client_id" => "oauth-test",
          "redirect_uri" => "https://client.example/callback",
          "code" => code,
          "code_verifier" => verifier
        },
        overrides
      )
    )
  end

  def token_request(params) do
    https_conn()
    |> put_req_header("content-type", "application/x-www-form-urlencoded")
    |> post("https://localhost:4443/oauth/token", URI.encode_query(params))
  end

  def tokens(user, overrides \\ %{}) do
    {code, verifier} = authorize(user, overrides)
    code |> exchange(verifier) |> json_response(200)
  end

  def refresh(token) do
    token_request(%{"grant_type" => "refresh_token", "client_id" => "oauth-test", "refresh_token" => token})
  end

  def bearer_conn(token) do
    put_req_header(https_conn(), "authorization", "Bearer " <> token)
  end
end
