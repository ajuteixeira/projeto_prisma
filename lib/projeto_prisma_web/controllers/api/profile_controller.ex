defmodule ProjetoPrismaWeb.Api.ProfileController do
  use ProjetoPrismaWeb, :controller

  alias ProjetoPrisma.Accounts
  alias ProjetoPrismaWeb.ApiJSON

  @doc """
  GET /api/profile — cartão de perfil do usuário autenticado: bio, avatar,
  contagem de seguidores/seguindo e conquistas fixadas (até 4, pela posição).
  """
  def show(conn, _params) do
    case Accounts.get_profile_with_user(conn.assigns.current_scope) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Perfil nao encontrado"})

      profile ->
        json(conn, %{
          profile:
            ApiJSON.profile_card(profile, %{
              followers_count: Accounts.count_profile_followers(profile.id),
              following_count: Accounts.count_profile_following(profile.id),
              pinned_achievements: Accounts.list_pinned_achievements_for_profile(profile.id)
            })
        })
    end
  end
end
