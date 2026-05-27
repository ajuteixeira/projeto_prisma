defmodule ProjetoPrismaWeb.PageControllerTest do
  use ProjetoPrismaWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/users/log-in"
  end
end
