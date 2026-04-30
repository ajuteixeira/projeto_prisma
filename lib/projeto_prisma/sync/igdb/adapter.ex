defmodule ProjetoPrisma.Sync.Igdb.Adapter do
  @moduledoc """
  Adapter IGDB que normaliza respostas do cliente HTTP para o formato genérico.

  IGDB é diferente das outras plataformas: não é uma plataforma de jogos,
  mas um serviço de enriquecimento. Seu papel é resolver o igdb_id de um
  jogo externo (Steam, PSN, etc) para evitar duplicatas no catalog.
  """

  alias ProjetoPrisma.Sync.Igdb.Client

  @doc """
  Resolve o igdb_id de um jogo externo.

  Retorna {:ok, igdb_id} ou {:error, reason}
  """
  def resolve_game_id(external_game_id, platform_id)
      when is_binary(external_game_id) and is_integer(platform_id) do
    query =
      [
        "fields id,game,uid,platform,category;",
        "where uid = \"#{escape_query(external_game_id)}\" & platform = #{platform_id};",
        "limit 1;"
      ]
      |> Enum.join(" ")

    case Client.request(:external_games, query) do
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

  @doc """
  Busca os dados do game na IGDB a partir do id interno da IGDB.
  """
  def get_game_by_id(igdb_id) when is_integer(igdb_id) do
    query =
      [
        "fields id,name,cover.url,first_release_date;",
        "where id = #{igdb_id};",
        "limit 1;"
      ]
      |> Enum.join(" ")

    case Client.request(:games, query) do
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

    case Client.request(:games, query) do
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
      cover_image: cover_url(raw["cover"]),
      icon_image: nil,
      logo_image: nil
    }
  end

  defp cover_url(%{"url" => url}), do: cover_url(url)
  defp cover_url(url) when is_binary(url), do: "https:" <> url
  defp cover_url(_), do: nil

  defp extract_igdb_game_id(%{"game" => game_id}) when is_integer(game_id), do: game_id
  defp extract_igdb_game_id(%{game: game_id}) when is_integer(game_id), do: game_id
  defp extract_igdb_game_id(_), do: nil

  defp default_game_fields do
    ["id", "name", "first_release_date", "cover.url", "platforms"]
  end

  defp escape_query(value) do
    value
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
  end
end
