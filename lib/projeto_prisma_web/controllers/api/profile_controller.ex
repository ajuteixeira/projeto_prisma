defmodule ProjetoPrismaWeb.Api.ProfileController do
  use ProjetoPrismaWeb, :controller

  alias ProjetoPrisma.Accounts
  alias ProjetoPrisma.Accounts.ProfileDashboard
  alias ProjetoPrismaWeb.ApiJSON

  # Tamanho de página padrão e máximo da lista de conquistas para fixar.
  @page_size 20
  @max_page_size 50

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

  @doc """
  GET /api/profile/achievements?q=&offset=&limit= — conquistas desbloqueadas do
  usuário para a pinagem, por jogo e nome; `q` filtra pelo nome da conquista ou
  do jogo. `position` vem preenchido nas já fixadas; `next_offset` é `nil` no fim.
  """
  def achievements(conn, params) do
    scope = conn.assigns.current_scope
    offset = parse_int(params["offset"], 0, 0, nil)
    limit = parse_int(params["limit"], @page_size, 1, @max_page_size)

    {results, rest} =
      scope
      |> Accounts.list_achieved_achievements(
        search: params["q"] || "",
        offset: offset,
        limit: limit + 1
      )
      |> Enum.split(limit)

    json(conn, %{
      results: Enum.map(results, &ApiJSON.pinned_achievement/1),
      next_offset: if(rest == [], do: nil, else: offset + limit)
    })
  end

  @doc """
  PUT /api/profile/pinned-achievements — substitui as conquistas fixadas.

  Body: %{"ids" => [profile_achievement_id, ...]} em ordem, até 4. Responde as
  fixadas atualizadas, ou `422` quando passa de 4 ou há conquista inválida.
  """
  def update_pinned(conn, params) do
    case Accounts.update_pinned_achievements(conn.assigns.current_scope, params["ids"] || []) do
      {:ok, pinned} ->
        json(conn, %{pinned_achievements: Enum.map(pinned, &ApiJSON.pinned_achievement/1)})

      {:error, :too_many_pins} ->
        error(conn, :unprocessable_entity, "Voce so pode fixar ate 4 conquistas.")

      {:error, :profile_not_found} ->
        not_found(conn)

      {:error, _reason} ->
        error(conn, :unprocessable_entity, "Escolha apenas conquistas concluidas.")
    end
  end

  defp parse_int(raw, default, min, max) do
    case Integer.parse(to_string(raw || "")) do
      {value, ""} when value >= min -> if max, do: min(value, max), else: value
      _ -> default
    end
  end

  defp error(conn, status, message) do
    conn
    |> put_status(status)
    |> json(%{error: message})
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
