defmodule ProjetoPrismaWeb.Plugs.Cors do
  @moduledoc """
  CORS da API JSON (`/api`) para clientes que rodam no navegador.

  Só as origens de `config :projeto_prisma, :cors_origins` recebem
  `access-control-allow-origin`; as demais seguem sem o header e o navegador
  bloqueia a resposta. O preflight (`OPTIONS`) de uma origem permitida é
  respondido aqui com `204`, porque o router não tem rotas `OPTIONS`.
  """

  import Plug.Conn

  @allowed_methods "GET, POST, PUT, PATCH, DELETE, OPTIONS"
  @allowed_headers "authorization, content-type"
  # Segundos que o navegador pode reaproveitar o preflight.
  @max_age "600"

  def init(opts), do: opts

  def call(%Plug.Conn{path_info: ["api" | _]} = conn, _opts) do
    case allowed_origin(conn) do
      nil ->
        conn

      origin ->
        conn
        |> put_resp_header("access-control-allow-origin", origin)
        |> put_resp_header("vary", "origin")
        |> answer_preflight()
    end
  end

  def call(conn, _opts), do: conn

  defp answer_preflight(%Plug.Conn{method: "OPTIONS"} = conn) do
    conn
    |> put_resp_header("access-control-allow-methods", @allowed_methods)
    |> put_resp_header("access-control-allow-headers", @allowed_headers)
    |> put_resp_header("access-control-max-age", @max_age)
    |> send_resp(:no_content, "")
    |> halt()
  end

  defp answer_preflight(conn), do: conn

  defp allowed_origin(conn) do
    with [origin] <- get_req_header(conn, "origin"),
         true <- origin in Application.get_env(:projeto_prisma, :cors_origins, []) do
      origin
    else
      _ -> nil
    end
  end
end
