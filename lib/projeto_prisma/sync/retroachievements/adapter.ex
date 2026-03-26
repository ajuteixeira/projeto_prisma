defmodule ProjetoPrisma.Sync.RetroAchievements.Adapter do
  @behaviour ProjetoPrisma.Sync.PlatformBehaviour

  alias ProjetoPrisma.Sync.RetroAchievements.Client

  @impl true
  def fetch_games(%{external_user_id: retroach_id, api_key: api_key}) do
    with {:ok, %{status: 200, body: body}} <- Client.get_owned_games(retroach_id, api_key) do
      games =
        body
        |> Enum.reject(&hardcore_mode?/1)
        |> Enum.map(&normalize_game/1)

      {:ok, games}
    else
      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp hardcore_mode?(%{"HardcoreMode" => 1}), do: true
  defp hardcore_mode?(%{"HardcoreMode" => "1"}), do: true
  defp hardcore_mode?(_), do: false

  defp normalize_game(raw) do
    %{
      external_game_id: to_string(raw["GameID"]),
      name: raw["Title"],
      cover_image: nil,
      icon_image: retroach_image_url(raw["ImageIcon"]),
      logo_image: nil,
      playtime_minutes: nil
    }
  end

  defp retroach_image_url(image_url) do
    "https://retroachievements.org#{image_url}"
  end

  @impl true
  def fetch_achievements(%{external_user_id: retroach_id, api_key: api_key}, external_game_id) do
    with {:ok, %{status: 200, body: body}} <-
           Client.get_player_achievements(retroach_id, api_key, external_game_id) do
      achievements =
        (body["Achievements"] || %{})
        |> Map.values()
        |> Enum.map(&normalize_achievement/1)

      {:ok, achievements}
    else
      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp normalize_achievement(raw) do
    unlock_time = parse_retroach_datetime(raw["DateEarnedHardcore"] || raw["DateEarned"])

    %{
      external_achievement_id: to_string(raw["ID"]),
      name: raw["Title"],
      description: raw["Description"],
      icon_image: achievement_icon_url(raw["BadgeName"]),
      icon_locked_image: achievement_locked_icon_url(raw["BadgeName"]),
      achieved: not is_nil(unlock_time),
      unlock_time: unlock_time
    }
  end

  defp achievement_icon_url(badge_name),
    do: "https://retroachievements.org/Badge/#{badge_name}.png"

  defp achievement_locked_icon_url(badge_name),
    do: "https://retroachievements.org/Badge/#{badge_name}_lock.png"

  defp parse_retroach_datetime(nil), do: nil
  defp parse_retroach_datetime(""), do: nil

  defp parse_retroach_datetime(value) when is_binary(value) do
    value
    |> String.replace(" ", "T")
    |> NaiveDateTime.from_iso8601()
    |> case do
      {:ok, datetime} -> datetime
      _ -> nil
    end
  end
end
