defmodule ProjetoPrisma.Sync.Igdb.Adapter do
  @moduledoc """
  Adapter IGDB que normaliza respostas do cliente HTTP para o formato genérico.

  IGDB é diferente das outras plataformas: não é uma plataforma de jogos,
  mas um serviço de enriquecimento. Seu papel é resolver o igdb_id de um
  jogo externo (Steam, PSN, etc) para evitar duplicatas no catalog.
  """

  alias ProjetoPrisma.Sync.Igdb.Client

  @igdb_external_platforms %{
    steam: [6],
    playstation: [167, 48, 9, 46, 7, 8],
    xbox: [169, 49, 12, 11]
  }

  @doc """
  Enriquece um jogo normalizado da plataforma com dados da IGDB.

  Quando a IGDB não tem vínculo por ID externo, tenta buscar pelo nome.
  Se ainda assim não encontrar, retorna os dados da própria plataforma para
  que o sync não descarte jogos/troféus por falta de enriquecimento.
  """
  def enrich_game(game_data, platform_slug) do
    external_game_id = get_value(game_data, :external_game_id)
    name = get_value(game_data, :name)

    with {:ok, igdb_id} <- resolve_game_id(external_game_id, platform_slug),
         {:ok, igdb_game} <- get_game_by_id(igdb_id) do
      {:ok, merge_platform_images(igdb_game, game_data)}
    else
      _ ->
        fallback_game_by_name(name, game_data)
    end
  end

  @doc """
  Resolve o igdb_id de um jogo externo.

  Retorna {:ok, igdb_id} ou {:error, reason}
  """
  def resolve_game_id(external_game_id, platform_slug)
      when is_binary(external_game_id) do
    platform_slug
    |> igdb_external_platform_ids()
    |> try_external_game_platforms(external_game_id)
  end

  def resolve_game_id(_, _), do: {:error, :invalid_external_game_id}

  defp try_external_game_platforms([], _external_game_id), do: {:error, :unsupported_platform}

  defp try_external_game_platforms([platform_id | rest], external_game_id) do
    case resolve_game_id_for_igdb_platform(external_game_id, platform_id) do
      {:error, _} -> try_external_game_platforms(rest, external_game_id)
      result -> result
    end
  end

  defp resolve_game_id_for_igdb_platform(external_game_id, platform_id) do
    query =
      [
        "fields id,game,uid,platform,category;",
        "where uid = \"#{escape_query(external_game_id)}\" & platform = #{platform_id};",
        "limit 1;"
      ]
      |> Enum.join(" ")

    case request(:external_games, query) do
      {:ok, %{status: 200, body: body}} ->
        case List.wrap(body) do
          [first | _] ->
            case extract_igdb_game_id(first) do
              nil -> {:error, :game_not_linked}
              game_id -> {:ok, game_id}
            end

          [] ->
            {:error, :not_found}
        end

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp igdb_external_platform_ids(slug) when is_atom(slug),
    do: Map.get(@igdb_external_platforms, slug, [])

  defp igdb_external_platform_ids(slug) when is_binary(slug) do
    case slug do
      "steam" -> Map.fetch!(@igdb_external_platforms, :steam)
      "playstation" -> Map.fetch!(@igdb_external_platforms, :playstation)
      "xbox" -> Map.fetch!(@igdb_external_platforms, :xbox)
      _ -> []
    end
  end

  @doc """
  Busca os dados do game na IGDB a partir do id interno da IGDB.
  """
  def get_game_by_id(igdb_id) when is_integer(igdb_id) do
    query =
      [
        "fields id,name,cover.url,artworks.url,first_release_date;",
        "where id = #{igdb_id};",
        "limit 1;"
      ]
      |> Enum.join(" ")

    case request(:games, query) do
      {:ok, %{status: 200, body: body}} ->
        case List.wrap(body) do
          [first | _] -> {:ok, normalize_game(first)}
          [] -> {:error, :not_found}
        end

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Busca jogos na IGDB por nome.

  Retorna {:ok, [games]} onde cada game está normalizado.
  """
  def search_games_by_name(name, opts \\ []) when is_binary(name) do
    fields = Keyword.get(opts, :fields, default_game_fields())
    limit = Keyword.get(opts, :limit, 10)

    query =
      [
        "fields #{Enum.join(fields, ",")};",
        "search \"#{escape_query(name)}\";",
        "limit #{limit};"
      ]
      |> Enum.join(" ")

    case request(:games, query) do
      {:ok, %{status: 200, body: body}} ->
        games =
          List.wrap(body)
          |> Enum.map(&normalize_game/1)

        {:ok, games}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp normalize_game(raw) do
    %{
      igdb_id: raw["id"],
      name: raw["name"],
      cover_image: artwork_url(raw["artworks"]) || cover_url(raw["cover"]),
      icon_image: nil,
      logo_image: nil
    }
  end

  defp fallback_game_by_name(nil, game_data), do: {:ok, platform_game_attrs(game_data)}

  defp fallback_game_by_name(name, game_data) when is_binary(name) do
    case search_games_by_name(name, limit: 1) do
      {:ok, [igdb_game | _]} -> {:ok, merge_platform_images(igdb_game, game_data)}
      _ -> {:ok, platform_game_attrs(game_data)}
    end
  end

  defp platform_game_attrs(game_data) do
    %{
      igdb_id: nil,
      name: get_value(game_data, :name),
      cover_image: get_value(game_data, :cover_image),
      icon_image: get_value(game_data, :icon_image),
      logo_image: get_value(game_data, :logo_image)
    }
  end

  defp merge_platform_images(igdb_game, game_data) do
    platform_cover = get_value(game_data, :cover_image)

    %{
      igdb_game
      | cover_image: igdb_game.cover_image || platform_cover,
        icon_image: igdb_game.icon_image || get_value(game_data, :icon_image) || platform_cover || igdb_game.cover_image,
        logo_image: igdb_game.logo_image || get_value(game_data, :logo_image)
    }
  end

  defp get_value(map, key) when is_map(map),
    do: Map.get(map, key) || Map.get(map, Atom.to_string(key))

  defp get_value(_, _), do: nil

  defp request(resource, query) do
    Client.request(resource, query)
  rescue
    System.EnvError -> {:error, :missing_igdb_credentials}
  end

  defp cover_url(%{"url" => url}), do: cover_url(url)

  defp cover_url(url) when is_binary(url) do
    url
    |> String.replace("t_thumb", "t_original")
    |> then(&("https:" <> &1))
  end

  defp cover_url(_), do: nil

  defp artwork_url([%{"url" => url} | _]), do: artwork_url(url)

  defp artwork_url(url) when is_binary(url) do
    url
    |> String.replace("t_thumb", "t_original")
    |> then(&("https:" <> &1))
  end

  defp artwork_url(_), do: nil

  defp extract_igdb_game_id(%{"game" => game_id}) when is_integer(game_id), do: game_id
  defp extract_igdb_game_id(%{game: game_id}) when is_integer(game_id), do: game_id
  defp extract_igdb_game_id(_), do: nil

  defp default_game_fields do
    ["id", "name", "first_release_date", "cover.url", "artworks.url", "platforms"]
  end

  defp escape_query(value) do
    value
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
  end
end
