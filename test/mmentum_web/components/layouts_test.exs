defmodule MmentumWeb.LayoutsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MmentumWeb.Layouts

  test "account menu renders the animated appearance cycle button" do
    html =
      render_component(&Layouts.account_menu/1,
        current_user: %{email: "james@example.com", full_name: "James Baldwin"}
      )

    assert html =~ ~s(id="account-appearance")
    assert html =~ ~s(phx-hook="ThemeToggle")
    assert html =~ "data-theme-cycle"
    assert html =~ "data-appearance-path"
    assert html =~ "data-appearance-track"
    assert html =~ "Auto"
    assert html =~ "Light"
    assert html =~ "Dark"
    refute html =~ "data-theme-preference"
  end
end
