defmodule MmentumWeb.PageControllerTest do
  use MmentumWeb.ConnCase

  test "GET / redirects guests to login", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/login"
  end

  test "log administration routes are not exposed", %{conn: conn} do
    for path <- ["/logs", "/logs/new", "/logs/1", "/logs/1/edit", "/logs/1/show/edit"] do
      assert get(recycle(conn), path).status == 404
    end
  end
end
