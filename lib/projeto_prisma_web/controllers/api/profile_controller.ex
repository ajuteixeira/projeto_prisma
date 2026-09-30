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
        not_found(conn)

      profile ->
        json(conn, %{profile: card(profile)})
    end
  end

  @doc """
  PATCH /api/profile — edita o perfil pela sheet "Editar perfil" do app.

  Body (todas opcionais): %{"full_name", "username", "bio", "avatar"}; o avatar é
  um data URL (JPG, PNG, GIF ou WebP, até 2 MB). Responde o cartão atualizado e
  o usuário, ou `422` com `%{"errors" => %{"campo" => [...]}}`.
  """
  def update(conn, params) do
    attrs = Map.take(params, ["full_name", "username", "bio", "avatar"])

    case Accounts.update_profile_details(conn.assigns.current_scope, attrs) do
      {:ok, {user, profile}} ->
        json(conn, %{user: ApiJSON.user(user), profile: card(profile)})

      {:error, :profile_not_found} ->
        not_found(conn)

      {:error, errors} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: errors})
    end
  end

  defp card(profile) do
    ApiJSON.profile_card(profile, %{
      followers_count: Accounts.count_profile_followers(profile.id),
      following_count: Accounts.count_profile_following(profile.id),
      pinned_achievements: Accounts.list_pinned_achievements_for_profile(profile.id)
    })
  end

  defp not_found(conn) do
    conn
    |> put_status(:not_found)
    |> json(%{error: "Perfil nao encontrado"})
  end
end
