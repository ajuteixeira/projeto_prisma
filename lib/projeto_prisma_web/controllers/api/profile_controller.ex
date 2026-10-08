defmodule ProjetoPrismaWeb.Api.ProfileController do
  use ProjetoPrismaWeb, :controller

  alias ProjetoPrisma.Accounts
  alias ProjetoPrisma.Accounts.ProfileDashboard
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

  @doc """
  GET /api/profile/stats — os mesmos números dos cards do perfil web: total de
  conquistas, média de conclusão, jogos perfeitos e a distribuição de troféus
  por plataforma (todas as plataformas, em % das conquistas desbloqueadas).
  """
  def stats(conn, _params) do
    case Accounts.get_profile_with_user(conn.assigns.current_scope) do
      nil ->
        not_found(conn)

      profile ->
        json(conn, %{
          stats: ProfileDashboard.stats(profile.id),
          platform_distribution: ProfileDashboard.platform_distribution(profile.id)
        })
    end
  end

  @doc """
  GET /api/profile/recently-played — jogos jogados recentemente ordenados por
  última vez jogado em ordem decrescente.

  Query params: limit (padrão 10), offset (padrão 0)
  """
  def recently_played(conn, params) do
    case Accounts.get_profile_with_user(conn.assigns.current_scope) do
      nil ->
        not_found(conn)

      profile ->
        limit = parse_positive_int(params["limit"], 10)
        offset = parse_positive_int(params["offset"], 0)

        games = Accounts.list_recently_played_games(profile.id, limit: limit, offset: offset)
        count = Accounts.count_recently_played_games(profile.id)

        json(conn, %{
          recently_played: Enum.map(games, &format_game/1),
          total: count,
          limit: limit,
          offset: offset
        })
    end
  end

  defp parse_positive_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {num, ""} when num > 0 -> num
      _ -> default
    end
  end

  defp parse_positive_int(value, default) when is_integer(value) and value > 0, do: value
  defp parse_positive_int(_value, default), do: default

  defp format_game(game) do
    %{
      id: game.id,
      game_name: game.platform_game.game.name,
      platform: game.platform_game.platform.slug,
      playtime_minutes: game.playtime_minutes,
      last_played: game.last_played
    }
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
