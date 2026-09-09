defmodule ProjetoPrismaWeb.Plugs.ApiAuth do
  @moduledoc """
  Autenticação da API JSON via Bearer token.

  O token é gerado em `Accounts.generate_api_token/1` (login/registro) e enviado
  pelo cliente no header `Authorization: Bearer <token>`.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  alias ProjetoPrisma.Accounts
  alias ProjetoPrisma.Accounts.Scope

  @doc """
  Resolve o usuário a partir do header `Authorization: Bearer <token>`
  e assigna `:current_scope`.
  """
  def fetch_api_user(conn, _opts) do
    with {:ok, token} <- bearer_token(conn),
         %{} = user <- Accounts.get_user_by_api_token(token) do
      assign(conn, :current_scope, Scope.for_user(user))
    else
      _ -> assign(conn, :current_scope, Scope.for_user(nil))
    end
  end

  @doc """
  Garante que há um usuário autenticado, respondendo 401 caso contrário.
  """
  def require_api_user(conn, _opts) do
    if conn.assigns[:current_scope] && conn.assigns.current_scope.user do
      conn
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Não autenticado"})
      |> halt()
    end
  end

  @doc """
  Extrai o token Bearer do header Authorization.
  """
  def bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] when byte_size(token) > 0 -> {:ok, token}
      _ -> :error
    end
  end
end
