defmodule ProjetoPrisma.Sync.Psn.Adapter do
  @behaviour ProjetoPrisma.Sync.PlatformBehaviour

  alias ProjetoPrisma.Sync.Psn.Client

  @impl true
  def fetch_games(%{external_user_id: psn_id, api_key: access_token}) do
    with {:ok, %{status: 200, body: body}} <- Client.get_owned_games(psn_id, access_token) do
      games =
        body["titles"]
        |> Enum.map(&normalize_game/1)

      {:ok, games}
    else
      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def fetch_achievements(%{external_user_id: psn_id, api_key: access_token}, _game_external_id) do
    with {:ok, %{status: 200, body: titles_body}} <-
           Client.get_player_trophy_titles(psn_id, access_token) do
      achievements =
        titles_body["trophyTitles"]
        |> Enum.flat_map(fn title ->
          npCommunicationId = title["npCommunicationId"]

          with {:ok, %{status: 200, body: player_trophy}} <-
                 Client.get_player_achievement(psn_id, npCommunicationId, access_token),
               {:ok, %{status: 200, body: detail_body}} <-
                 Client.get_detail_achievement(npCommunicationId, access_token) do
            player_trophy["trophies"]
            |> Enum.map(&normalize_achievement(&1, detail_body, title))
          else
            _ -> []
          end
        end)

      {:ok, achievements}
    else
      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp normalize_game(raw) do
    %{
      external_game_id: to_string(raw["titleId"]),
      name: raw["name"],
      cover_image: nil,
      icon_image: raw["imageUrl"],
      logo_image: raw["imageUrl"],
      playtime_minutes: raw["playDuration"]
    }
  end

  defp normalize_achievement(player_trophy, detail_body, title) do
    npCommunicationId = title["npCommunicationId"]
    # Busca o detalhe do troféu específico
    detail_trophy =
      detail_body["trophies"]
      |> Enum.find(&(&1["trophyId"] == player_trophy["trophyId"]))
      |> case do
        nil -> %{}
        trophy -> trophy
      end

    %{
      external_achievement_id: to_string(npCommunicationId),
      name: detail_trophy["trophyName"] || "",
      description: detail_trophy["trophyDetail"],
      icon_image: detail_trophy["trophyIconUrl"],
      icon_locked_image: title["trophyTitleIconUrl"],
      achieved: player_trophy["earned"] == true,
      unlock_time: parse_psn_datetime(player_trophy["earnedDateTime"])
    }
  end

  defp parse_psn_datetime(nil), do: nil
  defp parse_psn_datetime(""), do: nil

  defp parse_psn_datetime(value) when is_binary(value) do
    value
    |> String.replace(" ", "T")
    |> NaiveDateTime.from_iso8601()
    |> case do
      {:ok, datetime} -> datetime
      _ -> nil
    end
  end
end
