defmodule MmentumWeb.LayoutsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MmentumWeb.Layouts

  test "account menu renders the animated appearance preferences" do
    html =
      render_component(&Layouts.account_menu/1,
        current_user: %{email: "james@example.com", full_name: "James Baldwin"}
      )

    assert html =~ ~s(id="account-appearance")
    assert html =~ ~s(phx-hook="ThemeToggle")
    assert html =~ "data-appearance-path"

    for preference <- ~w(auto light dark) do
      assert html =~ ~s(data-theme-preference="#{preference}")
    end
  end
end
