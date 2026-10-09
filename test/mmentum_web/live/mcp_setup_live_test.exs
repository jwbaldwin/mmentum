defmodule MmentumWeb.MCPSetupLiveTest do
  use MmentumWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Mmentum.OAuth

  setup :register_and_log_in_user

  setup do
    original_clients = Application.fetch_env!(:mmentum, :oauth_clients)

    Application.put_env(:mmentum, :oauth_clients, [
      %{
        "id" => "cursor-public",
        "name" => "Cursor",
        "setup_client" => "cursor",
        "redirect_uris" => ["http://localhost:8787/callback"]
      },
      %{
        "id" => "opencode-public",
        "name" => "OpenCode",
        "setup_client" => "opencode",
        "redirect_uris" => ["http://127.0.0.1:19876/callback"]
      },
      %{
        "id" => "vscode-public",
        "name" => "VS Code",
        "setup_client" => "vscode",
        "redirect_uris" => ["https://client.example/vscode/callback"]
      },
      %{
        "id" => "claude-code-public",
        "name" => "Claude Code",
        "setup_client" => "claude-code",
        "redirect_uris" => ["http://localhost:19876/callback"]
      },
      %{
        "id" => "gemini-public",
        "name" => "Gemini CLI",
        "setup_client" => "gemini",
        "redirect_uris" => ["http://localhost:19876/oauth/callback"]
      },
      %{
        "id" => "codex-public",
        "name" => "Codex CLI",
        "setup_client" => "codex",
        "redirect_uris" => ["http://localhost:19876/callback/mmentum-specific"]
      },
      %{
        "id" => "chatgpt-public",
        "name" => "ChatGPT",
        "setup_client" => "chatgpt",
        "redirect_uris" => ["https://chatgpt.com/connector/oauth/mmentum-specific"]
      },
      %{
        "id" => "pi-public",
        "name" => "Pi",
        "setup_client" => "pi",
        "redirect_uris" => ["http://127.0.0.1:19879/callback/mmentum"]
      }
    ])

    on_exit(fn -> Application.put_env(:mmentum, :oauth_clients, original_clients) end)
  end

  test "setup requires login", %{conn: conn} do
    conn = conn |> recycle() |> init_test_session(%{}) |> get(~p"/users/connections/new")
    assert redirected_to(conn) == ~p"/login"
  end

  test "offers the requested clients and switches instructions through the URL", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/users/connections/new")

    for key <- ~w(cursor vscode claude-code opencode codex chatgpt claude gemini amp notion pi other) do
      assert has_element?(view, "#client-#{key}")
      view |> element("#client-#{key}") |> render_click()
      assert_patch(view, ~p"/users/connections/new?client=#{key}")
      assert has_element?(view, "#client-#{key}[aria-current=true]")
      assert has_element?(view, "#client-guide")
    end

    view |> element("#client-cursor") |> render_click()
    assert_patch(view, ~p"/users/connections/new?client=cursor")
    refute has_element?(view, "#registration-required")
    refute has_element?(view, "#client-claude-managed-agents")
  end

  test "Cursor install and manual configuration use the registered public client and read scope", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/users/connections/new?client=cursor")

    configuration =
      view |> element("#setup-step-1 code") |> render() |> Floki.parse_fragment!() |> Floki.text() |> Jason.decode!()

    assert get_in(configuration, ["mcpServers", "mmentum", "url"]) == OAuth.config().audience

    assert get_in(configuration, ["mcpServers", "mmentum", "auth"]) == %{
             "CLIENT_ID" => "cursor-public",
             "scopes" => ["mmentum:read"]
           }

    [install_url] = view |> element("#install-client") |> render() |> Floki.parse_fragment!() |> Floki.attribute("href")
    query = install_url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()
    assert query["name"] == "Mmentum"
    assert query["config"] |> Base.decode64!() |> Jason.decode!() == get_in(configuration, ["mcpServers", "mmentum"])
  end

  test "named clients use local publisher marks while other clients has no invented brand", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/users/connections/new")

    for key <- ~w(cursor vscode claude-code opencode codex chatgpt claude gemini amp notion pi) do
      sources =
        view |> element("#client-#{key}") |> render() |> Floki.parse_fragment!() |> Floki.attribute("img", "src")

      assert sources != []
      assert Enum.all?(sources, &File.regular?("priv/static" <> &1))
    end

    refute has_element?(view, "#client-other img")
  end

  test "OpenCode V2 configuration preserves the exact registered callback", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/users/connections/new?client=opencode")

    configuration =
      view |> element("#setup-step-1 code") |> render() |> Floki.parse_fragment!() |> Floki.text() |> Jason.decode!()

    assert get_in(configuration, ["mcp", "servers", "mmentum", "oauth"]) == %{
             "client_id" => "opencode-public",
             "scope" => "mmentum:read",
             "callback_port" => 19_876,
             "redirect_uri" => "http://127.0.0.1:19876/callback"
           }

    refute Map.has_key?(configuration["mcp"], "mmentum")
  end

  test "the agent prompt carries a ready configuration, browser approval, and read-only verification", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/users/connections/new?client=opencode")

    prompt =
      view |> element("#agent-setup-prompt [data-copy-content]") |> render() |> Floki.parse_fragment!() |> Floki.text()

    [_, configuration] = Regex.run(~r/\n(\{.*\})\n/s, prompt)
    server = configuration |> Jason.decode!() |> get_in(["mcp", "servers", "mmentum"])

    assert server["url"] == OAuth.config().audience
    assert server["oauth"]["client_id"] == "opencode-public"
    assert server["oauth"]["redirect_uri"] == "http://127.0.0.1:19876/callback"
    assert server["oauth"]["scope"] == "mmentum:read"
    assert prompt =~ "~/.config/opencode/opencode.jsonc"
    assert prompt =~ "browser"
    assert prompt =~ "list_habits"
    refute has_element?(view, "#manual-setup[open]")
  end

  test "VS Code install carries its own configuration shape and no invented scope override", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/users/connections/new?client=vscode")
    [install_url] = view |> element("#install-client") |> render() |> Floki.parse_fragment!() |> Floki.attribute("href")
    configuration = install_url |> URI.parse() |> Map.fetch!(:query) |> URI.decode() |> Jason.decode!()

    assert configuration["type"] == "http"
    assert configuration["url"] == OAuth.config().audience
    assert configuration["oauth"] == %{"clientId" => "vscode-public"}
  end

  test "ChatGPT uses its registered client ID with manual OAuth and no automatic-install promise", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/users/connections/new?client=chatgpt")

    assert has_element?(view, "#manual-setup[open]")
    assert has_element?(view, "#setup-step-2 code", "chatgpt-public")
    refute has_element?(view, "#registration-required")
    refute has_element?(view, "#install-client")
    refute has_element?(view, "#agent-setup-prompt")

    clients = Application.fetch_env!(:mmentum, :oauth_clients)
    Application.put_env(:mmentum, :oauth_clients, Enum.reject(clients, &(&1["setup_client"] == "chatgpt")))
    render_patch(view, ~p"/users/connections/new?client=cursor")
    render_patch(view, ~p"/users/connections/new?client=chatgpt")
    assert has_element?(view, "#registration-required")
    refute has_element?(view, "#setup-step-2 code")
  end

  test "native Pi uses its own callback setting and login command without adapter fields", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/users/connections/new?client=pi")

    configuration =
      view |> element("#setup-step-1 code") |> render() |> Floki.parse_fragment!() |> Floki.text() |> Jason.decode!()

    server = get_in(configuration, ["mcpServers", "mmentum"])
    assert server["url"] == OAuth.config().audience

    assert server["oauth"] == %{
             "clientId" => "pi-public",
             "scope" => "mmentum:read",
             "callbackUrl" => "http://127.0.0.1:19879/callback/mmentum"
           }

    refute Map.has_key?(server, "auth")
    refute Map.has_key?(server, "protocolVersion")
    assert has_element?(view, "#setup-step-2 code", "pi mcp login mmentum")
    assert has_element?(view, "#agent-setup-prompt [data-copy-content]", "without pi-mcp-adapter")
    assert has_element?(view, "#agent-setup-prompt [data-copy-content]", "callbackUrl")
    refute has_element?(view, "#manual-setup[open]")
  end

  test "Pi withholds setup when it cannot reproduce the registered callback exactly", %{conn: conn} do
    clients = Application.fetch_env!(:mmentum, :oauth_clients)

    for redirect <- [
          "http://localhost/callback",
          "http://127.0.0.1:0/callback",
          "http://127.0.0.1:80/callback",
          "http://127.0.0.1:19879/callback?required=value",
          "https://client.example/callback"
        ] do
      Application.put_env(
        :mmentum,
        :oauth_clients,
        Enum.map(clients, fn client ->
          if client["setup_client"] == "pi", do: Map.put(client, "redirect_uris", [redirect]), else: client
        end)
      )

      {:ok, view, _html} = live(conn, ~p"/users/connections/new?client=pi")
      assert has_element?(view, "#callback-required")
      refute has_element?(view, "#agent-setup-prompt")
      refute has_element?(view, "#setup-step-1")
    end
  end

  test "mapped client consent shows the requesting logo pointing to Mmentum", %{conn: conn} do
    {params, _verifier} =
      Mmentum.OAuthFixtures.authorization_params(%{
        "client_id" => "cursor-public",
        "redirect_uri" => "http://localhost:8787/callback",
        "scope" => "mmentum:read"
      })

    {consent, _fields} = Mmentum.OAuthFixtures.consent_form(conn, params)
    html = consent |> html_response(200) |> Floki.parse_document!()

    assert Floki.attribute(html, "#consent-requesting-app img", "src") == [
             "/images/mcp-clients/cursor-light.svg",
             "/images/mcp-clients/cursor-dark.svg"
           ]

    assert Floki.attribute(html, "#consent-mmentum img", "src") == ["/images/mmentum.svg"]
    assert html |> Floki.find("h1") |> Floki.text() |> String.trim() == "Cursor"
  end

  test "unregistered clients have instructions but no fabricated credentials or install action", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/users/connections/new?client=claude")

    assert has_element?(view, "#registration-required")
    refute has_element?(view, "#install-client")
    refute has_element?(view, "#agent-setup-prompt")
    refute has_element?(view, "#setup-step-1")
    assert has_element?(view, "#mcp-server-url code", OAuth.config().audience)
    assert has_element?(view, "#mcp-verify-prompt")
  end

  test "Claude Code's command uses the registered callback port and public read scope", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/users/connections/new?client=claude-code")
    command = view |> element("#setup-step-1 code") |> render() |> Floki.parse_fragment!() |> Floki.text()
    ["claude mcp add-json mmentum", configuration] = String.split(command, " '", parts: 2)
    configuration = configuration |> String.trim_trailing("'") |> Jason.decode!()

    assert configuration["url"] == OAuth.config().audience

    assert configuration["oauth"] == %{
             "clientId" => "claude-code-public",
             "callbackPort" => 19_876,
             "scopes" => "mmentum:read"
           }
  end

  test "Gemini configuration preserves the callback and omits a client secret", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/users/connections/new?client=gemini")

    configuration =
      view |> element("#setup-step-1 code") |> render() |> Floki.parse_fragment!() |> Floki.text() |> Jason.decode!()

    server = get_in(configuration, ["mcpServers", "mmentum"])

    assert server["httpUrl"] == OAuth.config().audience

    assert server["oauth"] == %{
             "enabled" => true,
             "clientId" => "gemini-public",
             "scopes" => ["mmentum:read"],
             "redirectUri" => "http://localhost:19876/oauth/callback"
           }
  end

  test "Codex configuration uses the exact registered endpoint-specific callback", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/users/connections/new?client=codex")

    assert has_element?(
             view,
             "#setup-step-1 code",
             "callback_url = \"http://localhost:19876/callback/mmentum-specific\""
           )

    assert has_element?(view, "#setup-step-1 code", "client_id = \"codex-public\"")
    assert has_element?(view, "#setup-step-2 code", "codex mcp login mmentum")
  end

  test "Claude Code cannot reproduce a registered callback query using only a port", %{conn: conn} do
    clients = Application.fetch_env!(:mmentum, :oauth_clients)

    Application.put_env(
      :mmentum,
      :oauth_clients,
      Enum.map(clients, fn client ->
        if client["setup_client"] == "claude-code",
          do: Map.put(client, "redirect_uris", ["http://localhost:19876/callback?required=value"]),
          else: client
      end)
    )

    {:ok, view, _html} = live(conn, ~p"/users/connections/new?client=claude-code")
    assert has_element?(view, "#callback-required")
    refute has_element?(view, "#setup-step-1")
    refute has_element?(view, "#agent-setup-prompt")
  end

  test "mobile selection updates the same guide and URL", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/users/connections/new")
    view |> element("#mobile-client-picker") |> render_change(%{"client" => "opencode"})
    assert_patch(view, ~p"/users/connections/new?client=opencode")
    assert has_element?(view, "#client-guide-title", "Set up OpenCode")
    assert has_element?(view, "#mobile-client option[selected][value=opencode]")
  end

  test "a registered app with the wrong callback explains the correction and withholds configuration", %{conn: conn} do
    clients = Application.fetch_env!(:mmentum, :oauth_clients)

    Application.put_env(
      :mmentum,
      :oauth_clients,
      Enum.map(clients, fn client ->
        if client["setup_client"] == "opencode",
          do: Map.put(client, "redirect_uris", ["https://client.example/wrong-callback"]),
          else: client
      end)
    )

    {:ok, view, _html} = live(conn, ~p"/users/connections/new?client=opencode")
    assert has_element?(view, "#callback-required")
    refute has_element?(view, "#registration-required")
    refute has_element?(view, "#setup-step-1")
  end

  test "Notion explains its registration limitation instead of promising a URL-only connection", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/users/connections/new?client=notion")
    assert has_element?(view, "#client-setup-note", "Notion requires a registration arrangement")
    refute has_element?(view, "#install-client")
  end

  test "query parameters cannot replace the server or approved credentials", %{conn: conn} do
    {:ok, view, _html} =
      live(conn, "/users/connections/new?client=cursor&client_id=unapproved&url=https://other.example/mcp")

    assert has_element?(view, "#mcp-server-url code", OAuth.config().audience)
    assert has_element?(view, "#setup-step-1 code", "cursor-public")
    refute has_element?(view, "#setup-step-1 code", "unapproved")

    render_patch(view, "/users/connections/new?client=not-a-client")
    assert_patch(view, ~p"/users/connections/new")
    assert has_element?(view, "#client-cursor[aria-current=true]")

    render_patch(view, "/users/connections/new?client=claude-managed-agents")
    assert_patch(view, ~p"/users/connections/new")
    assert has_element?(view, "#client-cursor[aria-current=true]")
  end
end
