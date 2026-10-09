defmodule MmentumWeb.MCPClientGuides do
  @moduledoc "Owns client-specific MCP setup instructions and public configuration examples"

  @clients [
    %{key: "cursor", name: "Cursor"},
    %{key: "vscode", name: "VS Code"},
    %{key: "claude-code", name: "Claude Code"},
    %{key: "opencode", name: "OpenCode"},
    %{key: "codex", name: "Codex CLI"},
    %{key: "claude", name: "Claude"},
    %{key: "gemini", name: "Gemini CLI"},
    %{key: "amp", name: "Amp CLI"},
    %{key: "notion", name: "Notion"},
    %{key: "claude-managed-agents", name: "Claude Managed Agents"},
    %{key: "other", name: "Other clients"}
  ]

  def list, do: @clients

  def build(client, server_url, registration) do
    guide = instructions(client.key, server_url, registration)

    Map.merge(guide, %{
      registration: registration,
      agent_prompt: agent_prompt(client, guide),
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
          "Use the install button, or merge this configuration.",
          configuration,
          ".cursor/mcp.json"
        ),
        step(
          "Authenticate",
          "Sign in to Mmentum when Cursor asks."
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
          "Use the install button, or merge this configuration.",
          configuration,
          ".vscode/mcp.json"
        ),
        step(
          "Start and authenticate",
          "MCP: List Servers → mmentum → Start Server. Sign in when prompted."
        )
      ],
      install_url: install_url("vscode", configuration),
      note: "Review the requested permissions before approving.",
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
          "Run this command.",
          command,
          "Terminal"
        ),
        step(
          "Authenticate",
          "/mcp → mmentum → Authenticate. Finish sign-in in your browser."
        )
      ],
      install_url: nil,
      note: "Claude Code sign-in still needs verification with this server.",
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
          "Merge this into your OpenCode V2 config.",
          configuration,
          "~/.config/opencode/opencode.jsonc"
        ),
        step(
          "Authenticate",
          "/mcps → mmentum → Authenticate. Finish sign-in in your browser."
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
          "Merge this into your Codex config.",
          configuration,
          "~/.codex/config.toml"
        ),
        step(
          "Authenticate",
          "Run this command and finish sign-in in your browser.",
          "codex mcp login mmentum",
          "Terminal"
        )
      ],
      install_url: nil,
      note: "Codex may request write access too. Review permissions before approving.",
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
          "Customize → Connectors → Add custom connector. Name it Mmentum and paste the server URL."
        ),
        step(
          "Use the approved OAuth client",
          "Sign in now → Use your own OAuth client. Enter this client ID; leave the secret blank.",
          client_id(registration),
          "Public client ID"
        ),
        step(
          "Approve and enable",
          "Sign in, then enable Mmentum from + → Connectors."
        )
      ],
      install_url: nil,
      note: "Requires a plan with custom connectors and a publicly reachable server.",
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
          "Merge this into your Gemini CLI settings.",
          configuration,
          "~/.gemini/settings.json"
        ),
        step(
          "Authenticate",
          "Run /mcp auth mmentum and finish sign-in in your browser."
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
          "Run this command to add the server.",
          "amp mcp add mmentum " <> shell_quote(server_url),
          "Terminal"
        ),
        step(
          "Configure manual OAuth",
          "Follow Amp's manual OAuth instructions with your administrator."
        )
      ],
      install_url: nil,
      note: "Amp's public-client sign-in still needs verification.",
      requirements:
        "Amp documents http://localhost:8976/oauth/callback. Verify its current public-client login before registering it.",
      docs_url: "https://ampcode.com/docs/customize/mcp"
    }
  end

  defp instructions("notion", _server_url, _registration) do
    %{
      steps: [
        step("Open your Custom Agent", "Settings → Tools & Access → Add connection → Custom MCP server."),
        step(
          "Add Mmentum",
          "Paste the server URL and choose OAuth."
        )
      ],
      install_url: nil,
      note: "Notion requires a registration arrangement; URL-only setup won't work.",
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
          "Claude Console → Credential vaults → Create vault → Add credential."
        ),
        step(
          "Choose MCP OAuth",
          "Enter the server URL after your administrator completes registration."
        )
      ],
      install_url: nil,
      note: "Managed Agents sign-in still needs verification.",
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
          "Add the server URL in your app's MCP settings. Choose Streamable HTTP."
        ),
        step(
          "Configure OAuth",
          "Use this client ID, the registered callback, and mmentum:read. Leave the secret blank.",
          client_id(registration),
          "Public client ID"
        ),
        step(
          "Authenticate",
          "Start authentication in your app and finish sign-in in your browser."
        )
      ],
      install_url: nil,
      note: "Requires pre-registered public OAuth support; URL-only setup won't work.",
      requirements:
        "Register the app's exact redirect URI before authentication. HTTPS is required except for supported local loopback callbacks.",
      docs_url: "https://modelcontextprotocol.io/docs/develop/connect-remote-servers"
    }
  end

  defp agent_prompt(client, guide) do
    first_step = hd(guide.steps)

    if client.key in ["cursor", "vscode", "claude-code", "opencode", "codex", "gemini"] and first_step.code do
      installation =
        if first_step.label == "Terminal" do
          "Run this command:"
        else
          "Merge this configuration into #{first_step.label}, preserving existing servers:"
        end

      authentication = Enum.at(guide.steps, 1)

      authentication_steps =
        [authentication.description, authentication.code] |> Enum.reject(&is_nil/1) |> Enum.join("\n")

      """
      Set up Mmentum in #{client.name}.

      #{installation}
      #{first_step.code}

      #{authentication_steps}
      Let me complete OAuth approval in my browser. Do not ask me to paste tokens or client secrets.
      After approval, call list_habits to show my habits and current progress. Do not change my habits.
      """
    end
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
