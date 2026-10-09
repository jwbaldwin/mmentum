defmodule MmentumWeb.MCPClientGuides do
  @moduledoc "Owns client-specific MCP setup instructions and public configuration examples"

  @clients [
    %{key: "cursor", name: "Cursor", description: "Editor and agents", icon: "hero-code-bracket"},
    %{key: "vscode", name: "VS Code", description: "Editor", icon: "hero-code-bracket-square"},
    %{key: "claude-code", name: "Claude Code", description: "Terminal", icon: "hero-command-line"},
    %{key: "opencode", name: "OpenCode", description: "Terminal", icon: "hero-command-line"},
    %{key: "codex", name: "Codex CLI", description: "Terminal", icon: "hero-command-line"},
    %{key: "claude", name: "Claude", description: "Web and desktop", icon: "hero-chat-bubble-left-right"},
    %{key: "gemini", name: "Gemini CLI", description: "Terminal", icon: "hero-command-line"},
    %{key: "amp", name: "Amp CLI", description: "Terminal", icon: "hero-command-line"},
    %{key: "notion", name: "Notion", description: "Custom Agents", icon: "hero-document-text"},
    %{
      key: "claude-managed-agents",
      name: "Claude Managed Agents",
      description: "Credential vaults",
      icon: "hero-cloud"
    },
    %{key: "other", name: "Other clients", description: "Manual setup", icon: "hero-link"}
  ]

  def list, do: @clients

  def build(client, server_url, registration) do
    guide = instructions(client.key, server_url, registration)

    Map.merge(guide, %{
      registration: registration,
      callback_missing?:
        not is_nil(registration) and client.key in ["claude-code", "opencode", "gemini"] and
          is_nil(hd(guide.steps).code)
    })
  end

  defp instructions("cursor", server_url, registration) do
    configuration =
      configuration(registration, fn client ->
        json(%{
          "mcpServers" => %{
            "mmentum" => %{
              "url" => server_url,
              "auth" => %{"CLIENT_ID" => client["id"], "scopes" => ["mmentum:read"]}
            }
          }
        })
      end)

    %{
      steps: [
        step(
          "Add Mmentum to Cursor",
          "Open Cursor Settings → Tools & MCP → New MCP Server. Add this configuration, or use the install button.",
          configuration,
          ".cursor/mcp.json"
        ),
        step(
          "Authenticate",
          "Select the authentication prompt and sign in to Mmentum. Review access, then return to Cursor. Restart Cursor if the server doesn't appear."
        )
      ],
      install_url: install_url("cursor", configuration),
      note: nil,
      requirements:
        "Register http://localhost:8787/callback for desktop, or https://www.cursor.com/agents/mcp/oauth/callback for web agents.",
      docs_url: "https://cursor.com/docs/context/mcp"
    }
  end

  defp instructions("vscode", server_url, registration) do
    configuration =
      configuration(registration, fn client ->
        json(%{
          "servers" => %{
            "mmentum" => %{
              "type" => "http",
              "url" => server_url,
              "oauth" => %{"clientId" => client["id"]}
            }
          }
        })
      end)

    %{
      steps: [
        step(
          "Add the server",
          "Open your workspace MCP configuration and add Mmentum. The install button can create the server entry for you.",
          configuration,
          ".vscode/mcp.json"
        ),
        step(
          "Start and authenticate",
          "Open the Command Palette → MCP: List Servers → mmentum → Start Server. Allow authentication, sign in to Mmentum, then return to VS Code."
        )
      ],
      install_url: install_url("vscode", configuration),
      note:
        "Review the permissions VS Code requests during approval; its configuration doesn't provide a documented scope override.",
      requirements:
        "Register the exact callback used by your VS Code installation. Its callback can differ between desktop and hosted surfaces.",
      docs_url: "https://code.visualstudio.com/docs/agents/reference/mcp-configuration"
    }
  end

  defp instructions("claude-code", server_url, registration) do
    callback = loopback_callback(registration, "localhost", "/callback")

    command =
      if callback && is_nil(callback.query) do
        configuration =
          json(%{
            "type" => "http",
            "url" => server_url,
            "oauth" => %{"clientId" => registration["id"], "callbackPort" => callback.port, "scopes" => "mmentum:read"}
          })

        "claude mcp add-json mmentum " <> shell_quote(configuration)
      end

    %{
      steps: [
        step(
          "Add the server",
          "Run this in your terminal. The configuration uses the approved public client and requests read access.",
          command,
          "Terminal"
        ),
        step(
          "Authenticate",
          "Start Claude Code, enter /mcp, select mmentum, and follow the browser sign-in. Review access and return to your terminal."
        )
      ],
      install_url: nil,
      note:
        "Current-client OAuth still needs verification. Earlier local checks reached token exchange but encountered a client-side token-storage issue.",
      requirements:
        "Register a fixed http://localhost:PORT/callback. Current Claude Code uses localhost; some earlier releases used 127.0.0.1.",
      docs_url: "https://code.claude.com/docs/en/mcp"
    }
  end

  defp instructions("opencode", server_url, registration) do
    callback = loopback_callback(registration, "127.0.0.1", "/callback")

    configuration =
      if callback do
        json(%{
          "$schema" => "https://opencode.ai/config.json",
          "mcp" => %{
            "servers" => %{
              "mmentum" => %{
                "type" => "remote",
                "url" => server_url,
                "oauth" => %{
                  "client_id" => registration["id"],
                  "scope" => "mmentum:read",
                  "callback_port" => callback.port,
                  "redirect_uri" => URI.to_string(callback)
                }
              }
            }
          }
        })
      end

    %{
      steps: [
        step(
          "Add the server",
          "Add this entry to your OpenCode V2 configuration. Merge it with existing servers rather than replacing your file.",
          configuration,
          "~/.config/opencode/opencode.jsonc"
        ),
        step(
          "Authenticate",
          "Start OpenCode, open /mcps, select mmentum, and authenticate. Sign in to Mmentum in your browser, review access, then return to OpenCode."
        )
      ],
      install_url: nil,
      note: nil,
      requirements:
        "Register a fixed http://127.0.0.1:PORT/callback. The generated V2 configuration uses that exact callback.",
      docs_url: "https://opencode.ai/v2/docs/mcp-servers"
    }
  end

  defp instructions("codex", server_url, registration) do
    configuration =
      configuration(registration, fn client ->
        callback = hd(client["redirect_uris"])

        "[mcp_servers.mmentum]\nurl = #{json(server_url)}\nscopes = [\"mmentum:read\"]\n\n" <>
          "[mcp_servers.mmentum.oauth]\nclient_id = #{json(client["id"])}\ncallback_url = #{json(callback)}"
      end)

    %{
      steps: [
        step(
          "Add the server",
          "Merge this into your Codex configuration. Your administrator must register the exact callback generated by Codex before login.",
          configuration,
          "~/.codex/config.toml"
        ),
        step(
          "Authenticate",
          "Run the login command, sign in to Mmentum, review access, and return to Codex. Restart an existing Codex session to load the server.",
          "codex mcp login mmentum",
          "Terminal"
        )
      ],
      install_url: nil,
      note:
        "Codex may request all scopes advertised by the server, even when read access is configured. Review the actual permissions during approval.",
      requirements:
        "Use codex mcp add mmentum --url SERVER_URL --oauth-client-id CLIENT_ID to obtain the callback. Register the exact printed URL; do not substitute a generic /callback.",
      docs_url: "https://developers.openai.com/codex/extend/mcp"
    }
  end

  defp instructions("claude", _server_url, registration) do
    %{
      steps: [
        step(
          "Add a custom connector",
          "In Claude web or desktop, open Customize → Connectors → Add custom connector. Name it Mmentum and paste the server URL above. Custom connectors may depend on your plan."
        ),
        step(
          "Use the approved OAuth client",
          "Choose Sign in now → Use your own OAuth client. In older dialogs, open Advanced settings. Enter the public client ID and leave the client secret blank.",
          client_id(registration),
          "Public client ID"
        ),
        step(
          "Approve and enable",
          "Sign in to Mmentum and review access. Back in Claude, enable Mmentum from the conversation's + menu → Connectors."
        )
      ],
      install_url: nil,
      note:
        "Claude remote connectors run in Anthropic's cloud, including when you use the desktop app. They cannot reach a server available only on your computer.",
      requirements:
        "Register https://claude.ai/api/mcp/auth_callback. Use the remote custom connector, not claude_desktop_config.json.",
      docs_url: "https://claude.com/docs/connectors/custom/add-unlisted"
    }
  end

  defp instructions("gemini", server_url, registration) do
    callback = loopback_callback(registration, "localhost", "/oauth/callback")

    configuration =
      if callback do
        json(%{
          "mcpServers" => %{
            "mmentum" => %{
              "httpUrl" => server_url,
              "oauth" => %{
                "enabled" => true,
                "clientId" => registration["id"],
                "scopes" => ["mmentum:read"],
                "redirectUri" => URI.to_string(callback)
              }
            }
          }
        })
      end

    %{
      steps: [
        step(
          "Add the server",
          "Merge this entry into your Gemini CLI settings. No client secret is needed for the approved public client.",
          configuration,
          "~/.gemini/settings.json"
        ),
        step(
          "Authenticate",
          "Start Gemini CLI, run /mcp auth mmentum, and follow the browser sign-in. Review access, then return to Gemini CLI."
        )
      ],
      install_url: nil,
      note: nil,
      requirements:
        "Register a fixed http://localhost:PORT/oauth/callback. The configuration uses that exact callback.",
      docs_url: "https://geminicli.com/docs/tools/mcp-server/"
    }
  end

  defp instructions("amp", server_url, _registration) do
    %{
      steps: [
        step(
          "Add the server",
          "This adds the endpoint to Amp. It does not complete authentication.",
          "amp mcp add mmentum " <> shell_quote(server_url),
          "Terminal"
        ),
        step(
          "Configure manual OAuth",
          "Amp documents manual login with a client ID and scopes. Its public-client flow without a secret still needs verification against Mmentum. Follow the current Amp documentation with your administrator."
        )
      ],
      install_url: nil,
      note:
        "Public-client authentication is not verified. Do not supply an invented client secret or assume URL-only registration will work.",
      requirements:
        "Amp documents http://localhost:8976/oauth/callback. Verify its current public-client login before registering it.",
      docs_url: "https://ampcode.com/docs/customize/mcp"
    }
  end

  defp instructions("notion", _server_url, _registration) do
    %{
      steps: [
        step("Open your Custom Agent", "Open Settings → Tools & Access → Add connection → Custom MCP server."),
        step(
          "Add Mmentum",
          "Paste the server URL above and choose OAuth. Connect only after the registration prerequisite below has been completed."
        )
      ],
      install_url: nil,
      note:
        "Notion requires a registration arrangement for servers without automatic client registration. Mmentum does not offer automatic registration, so this connection is not available just by pasting the URL.",
      requirements:
        "Notion must pre-register an application with Mmentum. Its documentation does not expose a user-entered client ID or callback override.",
      docs_url: "https://www.notion.com/help/mcp-connections-for-custom-agents"
    }
  end

  defp instructions("claude-managed-agents", _server_url, _registration) do
    %{
      steps: [
        step(
          "Open Credential vaults",
          "In the Claude Console, open Credential vaults → Create vault → Add credential."
        ),
        step(
          "Choose MCP OAuth",
          "Enter the Mmentum server URL. Complete client registration with your administrator before attempting the browser connection."
        )
      ],
      install_url: nil,
      note:
        "The Managed Agents browser authorization flow still needs verification. Its support for refreshing public-client tokens does not establish a working initial connection.",
      requirements:
        "Verify the Console's public-client authorization and exact callback. Do not reuse Claude web's callback without confirming it.",
      docs_url: "https://platform.claude.com/docs/en/managed-agents/vaults"
    }
  end

  defp instructions("other", _server_url, registration) do
    %{
      steps: [
        step(
          "Add a remote server",
          "In your app's MCP settings, add Mmentum using the server URL above. Select Streamable HTTP if it asks for a transport."
        ),
        step(
          "Configure OAuth",
          "Use the approved public client ID, request mmentum:read, and use an exactly registered callback URL. No client secret is needed.",
          client_id(registration),
          "Public client ID"
        ),
        step(
          "Authenticate",
          "Start authentication in your app. Sign in to Mmentum, review access, then return to your app."
        )
      ],
      install_url: nil,
      note:
        "Your app must support remote Streamable HTTP and pre-registered public OAuth clients. URL-only automatic registration is not available.",
      requirements:
        "Register the app's exact redirect URI before authentication. HTTPS is required except for supported local loopback callbacks.",
      docs_url: "https://modelcontextprotocol.io/docs/develop/connect-remote-servers"
    }
  end

  defp step(title, description, code \\ nil, label \\ nil) do
    %{title: title, description: description, code: code, label: label}
  end

  defp configuration(nil, _build), do: nil
  defp configuration(client, build), do: build.(client)
  defp client_id(nil), do: nil
  defp client_id(client), do: client["id"]

  defp loopback_callback(nil, _host, _path), do: nil

  defp loopback_callback(client, host, path) do
    client["redirect_uris"]
    |> Enum.map(&URI.parse/1)
    |> Enum.find(&(&1.scheme == "http" and &1.host == host and &1.path == path))
  end

  defp install_url(_client, nil), do: nil

  defp install_url("cursor", configuration) do
    "https://cursor.com/en/install-mcp?" <>
      URI.encode_query(%{
        "name" => "Mmentum",
        "config" => configuration |> Jason.decode!() |> get_in(["mcpServers", "mmentum"]) |> json() |> Base.encode64()
      })
  end

  defp install_url("vscode", configuration) do
    definition = configuration |> Jason.decode!() |> get_in(["servers", "mmentum"]) |> Map.put("name", "Mmentum")
    {:vscode, "mcp/install?" <> URI.encode(json(definition), &URI.char_unreserved?/1)}
  end

  defp json(value), do: Jason.encode!(value, pretty: true)
  defp shell_quote(value), do: "'" <> String.replace(value, "'", "'\\''") <> "'"
end
