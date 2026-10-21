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

  defp pinned_achievement(achievement) do
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

  defp avatar_url(%ProfileAvatar{data: data}) when is_binary(data) do
    data = String.trim(data)
    if String.starts_with?(data, "data:image"), do: data
  end

  defp avatar_url(_avatar), do: nil

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
