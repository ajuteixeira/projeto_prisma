defmodule ProjetoPrismaWeb.Api.ProfileController do
  use ProjetoPrismaWeb, :controller

  alias ProjetoPrisma.Accounts
  alias ProjetoPrisma.Accounts.ProfileDashboard
  alias ProjetoPrismaWeb.ApiJSON

  # Tamanho de página padrão e máximo das listas paginadas (conquistas e jogos).
  @page_size 20
  @max_page_size 50

  @doc """
  GET /api/profile — cartão de perfil do usuário autenticado: bio, avatar,
  contagem de seguidores/seguindo e conquistas fixadas (até 4, pela posição).

  GET /api/profiles/:username: o mesmo cartão para o perfil do username, só
  leitura, como a página `/:username` da web. `404` quando o username não existe.
  """
  def show(conn, _params) do
    with_profile(conn, fn profile -> json(conn, %{profile: card(profile)}) end)
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
  `GET /api/profiles/:username/stats` responde o mesmo para outro perfil.
  """
  def stats(conn, _params) do
    with_profile(conn, fn profile ->
      json(conn, %{
        stats: ProfileDashboard.stats(profile.id),
        platform_distribution: ProfileDashboard.platform_distribution(profile.id)
      })
    end)
  end

  @doc """
  GET /api/profile/recently-played — jogos jogados recentemente ordenados por
  última vez jogado em ordem decrescente.

  `GET /api/profiles/:username/recently-played` responde o mesmo para outro perfil.

  Query params: limit (padrão 10), offset (padrão 0)
  """
  def recently_played(conn, params) do
    with_profile(conn, fn profile ->
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
    end)
  end

  @doc """
  GET /api/profile/games?offset=&limit= — todos os jogos do perfil, como a lista
  "Jogos" da web, sempre do jogado mais recente ao mais antigo (os sem data por
  último). A ordem é fixa: não há parâmetro para mudá-la. `next_offset` é `nil`
  no fim.

  `GET /api/profiles/:username/games` responde o mesmo para outro perfil.
  """
  def games(conn, params) do
    with_profile(conn, fn profile ->
      offset = parse_int(params["offset"], 0, 0, nil)
      limit = parse_int(params["limit"], @page_size, 1, @max_page_size)

      {games, rest} =
        profile.id
        |> ProfileDashboard.list_games(limit + 1,
          offset: offset,
          sort_by: :last_played,
          sort_order: :desc
        )
        |> Enum.split(limit)

      json(conn, %{
        games: Enum.map(games, &ApiJSON.profile_game/1),
        next_offset: if(rest == [], do: nil, else: offset + limit)
      })
    end)
  end

  # O username vem só do caminho (`/api/profiles/:username`), para `?username=`
  # em `/api/profile` não trocar o perfil consultado.
  defp with_profile(conn, fun) do
    profile =
      case conn.path_params do
        %{"username" => username} -> Accounts.get_profile_with_user_by_username(username)
        _ -> Accounts.get_profile_with_user(conn.assigns.current_scope)
      end

    if profile, do: fun.(profile), else: not_found(conn)
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
  GET /api/profile/achievements/:id — detalhes de uma conquista do usuário, como
  o modal da web: nome, jogo, ícone, descrição e data de desbloqueio.
  """
  def achievement(conn, %{"id" => raw_id}) do
    id = parse_int(raw_id, nil, 1, nil)

    case Accounts.get_achievement_detail(conn.assigns.current_scope, id) do
      nil -> error(conn, :not_found, "Conquista nao encontrada")
      achievement -> json(conn, %{achievement: ApiJSON.achievement_detail(achievement)})
    end
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
