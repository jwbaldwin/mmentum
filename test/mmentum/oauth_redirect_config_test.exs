defmodule Mmentum.OAuthRedirectConfigTest do
  use ExUnit.Case, async: false

  setup do
    previous = System.get_env("OAUTH_PUBLIC_CLIENTS_JSON")

    on_exit(fn ->
      if previous,
        do: System.put_env("OAUTH_PUBLIC_CLIENTS_JSON", previous),
        else: System.delete_env("OAUTH_PUBLIC_CLIENTS_JSON")
    end)
  end

  test "runtime configuration rejects remote HTTP and malformed OAuth callbacks" do
    for redirect <- [
          "http://example.com/callback",
          "http://localhost.example.com/callback",
          "/callback",
          "https:///callback",
          "https://example.com/callback#fragment",
          "https://user@example.com/callback"
        ] do
      configure_redirect(redirect)

      assert_raise ArgumentError, fn ->
        Config.Reader.read!("config/runtime.exs", env: :test)
      end
    end
  end

  test "runtime configuration accepts HTTPS and loopback callbacks" do
    for redirect <- [
          "https://example.com/callback",
          "http://localhost:19878/callback",
          "http://127.0.0.1:19877/callback",
          "http://[::1]:19877/callback"
        ] do
      configure_redirect(redirect)
      config = Config.Reader.read!("config/runtime.exs", env: :test)
      assert hd(config[:mmentum][:oauth_clients])["redirect_uris"] == [redirect]
    end
  end

  test "setup guide metadata is optional and valid mapped registrations retain their public configuration" do
    client = %{
      "id" => "cursor-public",
      "name" => "Cursor",
      "setup_client" => "cursor",
      "redirect_uris" => ["http://localhost:8787/callback"]
    }

    System.put_env("OAUTH_PUBLIC_CLIENTS_JSON", Jason.encode!([client]))
    config = Config.Reader.read!("config/runtime.exs", env: :test)
    assert config[:mmentum][:oauth_clients] == [client]
  end

  test "setup guide metadata rejects unknown keys, duplicate mappings, and incomplete registrations" do
    client = %{
      "id" => "cursor-public",
      "name" => "Cursor",
      "setup_client" => "cursor",
      "redirect_uris" => ["http://localhost:8787/callback"]
    }

    for clients <- [
          [Map.put(client, "setup_client", "not-a-client")],
          [Map.put(client, "setup_client", 123)],
          [client, Map.put(client, "id", "another-cursor")],
          [Map.delete(client, "name")],
          [Map.put(client, "redirect_uris", [])]
        ] do
      System.put_env("OAUTH_PUBLIC_CLIENTS_JSON", Jason.encode!(clients))
      assert_raise ArgumentError, fn -> Config.Reader.read!("config/runtime.exs", env: :test) end
    end
  end

  defp configure_redirect(redirect) do
    System.put_env(
      "OAUTH_PUBLIC_CLIENTS_JSON",
      Jason.encode!([%{"id" => "redirect-test", "redirect_uris" => [redirect]}])
    )
  end
end
