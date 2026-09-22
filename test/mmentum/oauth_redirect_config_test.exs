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

  defp configure_redirect(redirect) do
    System.put_env(
      "OAUTH_PUBLIC_CLIENTS_JSON",
      Jason.encode!([%{"id" => "redirect-test", "redirect_uris" => [redirect]}])
    )
  end
end
