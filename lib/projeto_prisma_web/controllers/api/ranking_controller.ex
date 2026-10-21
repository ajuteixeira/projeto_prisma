defmodule ProjetoPrismaWeb.Api.RankingController do
  use ProjetoPrismaWeb, :controller

  alias ProjetoPrisma.Accounts
  alias ProjetoPrismaWeb.ApiJSON

  @doc """
  GET /api/ranking — o mesmo ranking da web: o usuário autenticado e quem ele
  segue, ordenados pelo total de conquistas desbloqueadas. Filtro por
  plataforma e busca ficam no cliente, a partir de `platform_counts`.
  """
  def index(conn, _params) do
    case Accounts.get_profile_with_user(conn.assigns.current_scope) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Perfil nao encontrado"})

      profile ->
        ranking = Accounts.ranking_for_profile(profile.id)
        json(conn, %{ranking: Enum.map(ranking, &ApiJSON.ranking_entry/1)})
    end
  end
end
