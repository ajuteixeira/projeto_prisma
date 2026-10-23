defmodule ProjetoPrismaWeb.ApiJSON do
  @moduledoc """
  Serializers JSON compartilhados pelos controllers da API.
  """

  alias ProjetoPrisma.Accounts.{Profile, ProfileAvatar, ProfilePlatformAccount, User}

  def user(%User{} = user) do
    %{
      id: user.id,
      email: user.email,
      username: user.username,
      full_name: user.full_name
    }
  end

  def profile(nil), do: nil

  def profile(%Profile{} = profile) do
    %{
      id: profile.id,
      username: profile.username
    }
  end

  @doc """
  Cartão de perfil (`GET /api/profile`). O avatar só sai quando é um data URL
  de imagem, como a web exige; do contrário o cliente usa o avatar gerado.
  """
  def profile_card(%Profile{} = profile, %{
        followers_count: followers_count,
        following_count: following_count,
        pinned_achievements: pinned_achievements
      }) do
    %{
      id: profile.id,
      username: profile.username,
      bio: profile.bio,
      avatar_url: avatar_url(profile.avatar),
      followers_count: followers_count,
      following_count: following_count,
      pinned_achievements: Enum.map(pinned_achievements, &pinned_achievement/1)
    }
  end

  def achievement_detail(achievement) do
    achievement
    |> pinned_achievement()
    |> Map.merge(%{
      description: achievement.description,
      unlocked_at: achievement.unlock_time
    })
  end

  def pinned_achievement(achievement) do
    %{
      id: achievement.profile_achievement_id,
      name: achievement.name,
      game_name: achievement.game_name,
      icon_url: achievement.icon_image,
      position: achievement.pinned_position
    }
  end

  @doc """
  Linha do ranking (`GET /api/ranking`): o perfil, o total de conquistas, as
  contagens por plataforma e as plataformas vinculadas.
  """
  def ranking_entry(%{profile: %Profile{} = profile} = entry) do
    %{
      profile_id: profile.id,
      username: profile.username,
      avatar_url: avatar_url(profile.avatar),
      achievement_count: entry.achievement_count,
      platform_counts: entry.platform_counts,
      platforms: entry.platform_slugs,
      is_current_user: entry.is_current_user
    }
  end

  @doc """
  Pessoa nas listas de seguidores (`/api/follows`): nome de exibição como na
  web (nome completo ou, na falta dele, o username) e se o usuário a segue.
  """
  def follow_profile(%Profile{} = profile, following_ids) do
    %{
      profile_id: profile.id,
      username: profile.username,
      display_name: display_name(profile),
      avatar_url: avatar_url(profile.avatar),
      is_following: MapSet.member?(following_ids, profile.id)
    }
  end

  defp display_name(%Profile{user: %User{full_name: name}, username: username})
       when is_binary(name) do
    case String.trim(name) do
      "" -> username
      name -> name
    end
  end

  defp display_name(%Profile{username: username}), do: username

  defp avatar_url(%ProfileAvatar{data: data}) when is_binary(data) do
    data = String.trim(data)
    if String.starts_with?(data, "data:image"), do: data
  end

  defp avatar_url(_avatar), do: nil

  @doc """
  Jogo da lista do perfil (`GET /api/profile/games`), a partir de
  `ProfileDashboard.list_games/3`. Como na web, a capa cai para o ícone e o
  ícone para a capa; `last_played_at` vem sem fuso.
  """
  def profile_game(game) do
    cover = present_image(game.game_cover_image)
    icon = present_image(game.game_icon_image)

    %{
      id: game.profile_game_id,
      name: game.game_name,
      cover_url: cover || icon,
      icon_url: icon || cover,
      platform: %{slug: game.platform_slug, name: game.platform_name},
      playtime_minutes: game.playtime_minutes,
      last_played_at: game.last_played,
      unlocked_achievements: game.unlocked_achievements,
      total_achievements: game.total_achievements,
      completion_percent: game.completion_percent
    }
  end

  @doc """
  Jogo da tela de detalhes (`GET /api/profile/games/:id`): o mesmo jogo da lista
  e a data do último desbloqueio, sem fuso.
  """
  def profile_game_detail(game) do
    game
    |> profile_game()
    |> Map.put(:last_unlock_at, game.last_unlock_time)
  end

  @doc """
  Conquista da tela do jogo (`GET /api/profile/games/:id/achievements`). Como no
  modal da web, a desbloqueada usa o ícone aceso e a bloqueada o apagado, caindo
  um para o outro quando falta.
  """
  def game_achievement(achievement) do
    icon = present_image(achievement.icon_image)
    locked_icon = present_image(achievement.icon_locked_image)

    %{
      id: achievement.id,
      name: achievement.name,
      description: achievement.description,
      icon_url: if(achievement.achieved, do: icon || locked_icon, else: locked_icon || icon),
      achieved: achievement.achieved,
      unlocked_at: achievement.unlock_time
    }
  end

  defp present_image(url) when is_binary(url) and url != "", do: url
  defp present_image(_url), do: nil

  def platform_account(%ProfilePlatformAccount{} = account) do
    %{
      platform: account.platform.slug,
      external_user_id: account.external_user_id,
      profile_url: account.profile_url,
      sync_status: account.sync_status
    }
  end

  @doc """
  Serializa o retorno de `SyncService.status/1`.

  Sem execução em memória, `running` é `false` e os contadores são `0`.
  `current.games_total` é `nil` até a plataforma retornar a lista de jogos.
  """
  def sync_status(%{progress: progress, accounts: accounts}) do
    progress = progress || %{}

    %{
      running: Map.get(progress, :running, false),
      started_at: Map.get(progress, :started_at),
      finished_at: Map.get(progress, :finished_at),
      accounts_total: Map.get(progress, :accounts_total, 0),
      accounts_done: Map.get(progress, :accounts_done, 0),
      accounts_failed: Map.get(progress, :accounts_failed, 0),
      games_synced: Map.get(progress, :games_synced, 0),
      achievements_synced: Map.get(progress, :achievements_synced, 0),
      current: Map.get(progress, :current),
      platforms:
        Enum.map(accounts, fn account ->
          %{platform: account.platform.slug, sync_status: account.sync_status}
        end)
    }
  end

  def changeset_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
