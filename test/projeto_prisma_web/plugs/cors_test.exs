defmodule ProjetoPrismaWeb.Plugs.CorsTest do
  use ProjetoPrismaWeb.ConnCase, async: true

  # Origem liberada em `config/test.exs`.
  @origin "http://app.test"

  defp preflight(conn, origin) do
    conn
    |> put_req_header("origin", origin)
    |> put_req_header("access-control-request-method", "POST")
    |> put_req_header("access-control-request-headers", "content-type")
    |> options(~p"/api/auth/login")
  end

  test "responde o preflight de uma origem liberada", %{conn: conn} do
    conn = preflight(conn, @origin)

    assert conn.status == 204
    assert get_resp_header(conn, "access-control-allow-origin") == [@origin]
    assert [methods] = get_resp_header(conn, "access-control-allow-methods")
    assert methods =~ "POST"

    assert get_resp_header(conn, "access-control-allow-headers") == [
             "authorization, content-type"
           ]
  end

  test "não libera uma origem fora da lista", %{conn: conn} do
    conn = preflight(conn, "http://outro.site")

    assert get_resp_header(conn, "access-control-allow-origin") == []
  end

  test "inclui o header nas respostas da API", %{conn: conn} do
    conn =
      conn
      |> put_req_header("origin", @origin)
      |> post(~p"/api/auth/login", %{})

    assert conn.status == 400
    assert get_resp_header(conn, "access-control-allow-origin") == [@origin]
  end

  test "não altera rotas fora de /api", %{conn: conn} do
    conn =
      conn
      |> put_req_header("origin", @origin)
      |> get(~p"/users/log-in")

    assert get_resp_header(conn, "access-control-allow-origin") == []
  end
end
