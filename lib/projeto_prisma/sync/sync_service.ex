defmodule ProjetoPrisma.Sync.SyncService do
  @moduledoc """
  Serviço de orquestração para sincronizar dados de plataformas.

  Coordena o fluxo completo:
  1. Busca dados do adapter (Steam, PlayStation, etc)
  2. Persiste games e achievements via Catalog
  3. Persiste dados de usuário via Accounts
  """

  alias ProjetoPrisma.{Catalog, Accounts, Repo}
  alias ProjetoPrisma.Sync.Adapters
  alias ProjetoPrisma.Sync.Igdb.Adapter, as: IgdbAdapter

  @doc """
  Sincroniza games e achievements de um usuário em uma plataforma.

  ## Parâmetros
    - `profile_id` - ID do perfil do usuário
    - `platform_slug` - "steam", "playstation", "xbox"
    - `external_user_id` - ID do usuário na plataforma
    - `api_key` - Chave API da plataforma

  ## Exemplos
      iex> sync_profile(1, :steam, "76561198310494902", "API_KEY")
      {:ok, %{games_synced: 5, achievements_synced: 42}}
  """
  def sync_profile(profile_id, platform_slug, external_user_id, api_key) do
    with :ok <- validate_profile(profile_id),
         {:ok, platform} <- get_platform(platform_slug),
         {:ok, adapter} <- get_adapter(platform_slug),
         {:ok, _} <- create_profile_platform_account(profile_id, platform.id, external_user_id),
         {:ok, stats} <-
           sync_games_and_achievements(
             profile_id,
             platform.id,
             adapter,
             external_user_id,
             api_key
           ) do
      {:ok, stats}
    else
      error -> error
    end
  end

  @doc """
  Sincroniza todas as contas de plataforma conectadas de um profile.
  """
  def sync_connected_platforms(profile_id) do
    with :ok <- validate_profile(profile_id) do
      profile_platform_accounts = Accounts.list_connected_platform_accounts(profile_id)

      summary =
        Enum.reduce(profile_platform_accounts, %{synced: 0, failed: 0, games_synced: 0, achievements_synced: 0}, fn account, acc ->
          case Accounts.mark_platform_sync_started(account, "sync_profile") do
            {:ok, running_account} ->
              case sync_profile(profile_id, running_account.platform.slug, running_account.external_user_id, running_account.api_key) do
                {:ok, %{games_synced: games_synced, achievements_synced: achievements_synced}} ->
                  _ = Accounts.mark_platform_sync_finished(running_account, "sync_profile")

                  %{
                    acc
                    | synced: acc.synced + 1,
                      games_synced: acc.games_synced + games_synced,
                      achievements_synced: acc.achievements_synced + achievements_synced
                  }

                {:error, reason} ->
                  _ = Accounts.mark_platform_sync_failed(running_account, "sync_profile", reason)
                  %{acc | failed: acc.failed + 1}
              end

            {:error, _reason} ->
              %{acc | failed: acc.failed + 1}
          end
        end)

      {:ok, summary}
    end
  end

  # Valida que o profile existe
  defp validate_profile(profile_id) do
    case Accounts.get_profile(profile_id) do
      nil -> {:error, :profile_not_found}
      _profile -> :ok
    end
  end

  # Busca a plataforma
  defp get_platform(platform_slug) do
    slug = platform_slug_to_string(platform_slug)

    case Repo.get_by(Catalog.Platform, slug: slug) do
      nil -> {:error, :platform_not_found}
      platform -> {:ok, platform}
    end
  end

  # Retorna o adapter
  defp get_adapter(platform_slug) do
    case Adapters.get_adapter(platform_slug_to_atom(platform_slug)) do
      {:error, _} = err -> err
      adapter -> {:ok, adapter}
    end
  end

  # Converte platform_slug para string
  defp platform_slug_to_string(slug) when is_atom(slug) do
    Atom.to_string(slug)
  end

  defp platform_slug_to_string(slug) when is_binary(slug) do
    slug
  end

  # Converte platform_slug para atom
  defp platform_slug_to_atom(slug) when is_binary(slug) do
    String.to_atom(slug)
  end

  defp platform_slug_to_atom(slug) when is_atom(slug) do
    slug
  end

  # Cria ou busca conta de plataforma do usuário
  defp create_profile_platform_account(profile_id, platform_id, external_user_id) do
    Accounts.get_or_create_platform_account(profile_id, platform_id, %{
      "external_user_id" => external_user_id
    })
  end

  # Sincroniza todos os games e achievements
  defp sync_games_and_achievements(profile_id, platform_id, adapter, external_user_id, api_key) do
    account = %{external_user_id: external_user_id, api_key: api_key}

    with {:ok, games} <- adapter.fetch_games(account) do
      stats = sync_all_games(profile_id, platform_id, adapter, account, games)
      {:ok, stats}
    else
      error -> error
    end
  end

  # Sincroniza cada game
  defp sync_all_games(profile_id, platform_id, adapter, account, games) do
    games_synced = 0
    achievements_synced = 0

    Enum.reduce(games, {games_synced, achievements_synced}, fn game, {g_count, a_count} ->
      case sync_single_game(profile_id, platform_id, adapter, account, game) do
        {:ok, achievements_count} ->
          {g_count + 1, a_count + achievements_count}

        {:error, _reason} ->
          {g_count, a_count}
      end
    end)
    |> build_response()
  end

  # Sincroniza um game específico e seus achievements
  defp sync_single_game(profile_id, platform_id, adapter, account, game_data) do
    with {:ok, igdb_id} <- IgdbAdapter.resolve_game_id(game_data.external_game_id, platform_id),
         {:ok, igdb_game} <- IgdbAdapter.get_game_by_id(igdb_id),
         {:ok, game} <- Catalog.get_or_create_game(igdb_game),
         {:ok, platform_game} <-
           Catalog.get_or_create_platform_game(
             platform_id,
             game.id,
             %{"external_game_id" => game_data.external_game_id}
           ),
         {:ok, profile_game} <-
           Accounts.get_or_create_profile_game(
             profile_id,
             platform_game.id,
             %{
               "playtime_minutes" => game_data.playtime_minutes || 0,
               "last_played" => DateTime.utc_now() |> DateTime.to_naive()
             }
           ),
         {:ok, achievements} <- adapter.fetch_achievements(account, game_data.external_game_id) do
      achievements_count = sync_achievements(profile_game.id, platform_game.id, achievements)
      {:ok, achievements_count}
    else
      error -> error
    end
  end

  # Sincroniza achievements de um game
  defp sync_achievements(profile_game_id, platform_game_id, achievements) do
    Enum.reduce(achievements, 0, fn ach_data, count ->
      case Catalog.get_or_create_achievement(platform_game_id, ach_data) do
        {:ok, achievement} ->
          Accounts.get_or_create_profile_achievement(
            profile_game_id,
            achievement.id,
            %{
              "achieved" => ach_data.achieved || false,
              "unlock_time" => ach_data.unlock_time
            }
          )

          count + 1

        {:error, _reason} ->
          count
      end
    end)
  end

  # Constrói resposta com estatísticas
  defp build_response({games_synced, achievements_synced}) do
    %{
      games_synced: games_synced,
      achievements_synced: achievements_synced
    }
  end
end
