defmodule MmentumWeb.PageControllerTest do
  use MmentumWeb.ConnCase

  test "GET / redirects guests to login", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/users/log_in"
  end
end
