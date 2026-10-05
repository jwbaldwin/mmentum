defmodule MmentumWeb.BrowserSecurityTest do
  use MmentumWeb.ConnCase, async: true

  test "browser pages restrict scripts and load the theme before app assets", %{conn: conn} do
    conn = get(conn, ~p"/login")
    [policy] = get_resp_header(conn, "content-security-policy")

    directives =
      Map.new(String.split(policy, "; "), fn directive ->
        [name | values] = String.split(directive)
        {name, values}
      end)

    assert directives["default-src"] == ["'self'"]
    assert directives["object-src"] == ["'none'"]
    refute "'unsafe-inline'" in directives["script-src"]
    refute "'unsafe-eval'" in directives["script-src"]
    assert Enum.any?(directives["connect-src"], &String.starts_with?(&1, "ws"))

    document = conn |> html_response(200) |> Floki.parse_document!()
    [theme | _scripts] = Floki.find(document, "script")
    assert Floki.attribute(theme, "src") == ["/assets/theme.js"]
    assert Floki.attribute(theme, "defer") == []
    assert Floki.attribute(theme, "async") == []
    assert Enum.all?(Floki.find(document, "script"), &(Floki.text(&1) == ""))
  end
end
