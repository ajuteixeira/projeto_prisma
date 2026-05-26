defmodule ProjetoPrisma.Sync.Psn.Adapter do
  @behaviour ProjetoPrisma.Sync.PlatformBehaviour

  alias ProjetoPrisma.Sync.Psn.Client
  alias ProjetoPrisma.Utils.Psn.Psn_Auth

  @impl true
  def fetch_games(%{external_user_id: psn_id, api_key: npsso}) do
    with {:ok, auth_tokens} <- Psn_Auth.authenticate(npsso),
         access_token = auth_tokens[:access_token],
         {:ok, %{status: 200, body: trophy_body}} <-
           Client.get_player_trophy_titles(psn_id, access_token),
         {:ok, %{status: 200, body: owned_body}} <- Client.get_owned_games(psn_id, access_token) do
      playtime_map =
        owned_body["titles"]
        |> Enum.reduce(%{}, fn raw, acc ->
          current = Map.get(acc, raw["name"], 0)
          Map.put(acc, raw["name"], current + parse_play_duration(raw["playDuration"]))
        end)

      games =
        trophy_body["trophyTitles"]
        |> dedupe_trophy_titles()
        |> Enum.map(&normalize_game(&1, playtime_map))

      {:ok, games}
    else
      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def fetch_achievements(%{external_user_id: psn_id, api_key: npsso}, game_ref) do
    {game_external_id, np_service_name} = achievement_game_ref(game_ref)

    with {:ok, auth_tokens} <- Psn_Auth.authenticate(npsso),
         access_token = auth_tokens[:access_token],
         {:ok, %{status: 200, body: player_trophy}} <-
           Client.get_player_achievement(psn_id, game_external_id, access_token, np_service_name),
         {:ok, %{status: 200, body: detail_body}} <-
           Client.get_detail_achievement(game_external_id, access_token, np_service_name) do
      achievements =
        player_trophy["trophies"]
        |> List.wrap()
        |> Enum.map(
          &normalize_achievement(&1, detail_body, %{"npCommunicationId" => game_external_id})
        )

      {:ok, achievements}
    else
      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # PSN returns one trophyTitle per console version (PS4/PS5), so the same
  # game can appear multiple times with different npCommunicationId. Collapse
  # by trophyTitleName, keeping the entry with the highest progress (tie-break
  # by most recent lastUpdatedDateTime) so the user sees their best run.
  defp dedupe_trophy_titles(titles) when is_list(titles) do
    titles
    |> Enum.group_by(& &1["trophyTitleName"])
    |> Enum.map(fn {_name, group} -> Enum.max_by(group, &trophy_title_rank/1) end)
  end

  defp dedupe_trophy_titles(_), do: []

  defp trophy_title_rank(title) do
    progress = title["progress"] || 0
    updated = title["lastUpdatedDateTime"] || ""
    {progress, updated}
  end

  defp normalize_game(raw, playtime_map) do
    %{
      external_game_id: raw["npCommunicationId"],
      name: raw["trophyTitleName"],
      cover_image: nil,
      icon_image: raw["trophyTitleIconUrl"],
      logo_image: raw["trophyTitleIconUrl"],
      np_service_name: raw["npServiceName"],
      playtime_minutes: Map.get(playtime_map, raw["trophyTitleName"], 0)
    }
  end

  defp achievement_game_ref(%{} = game_ref) do
    {
      Map.get(game_ref, :external_game_id) || Map.get(game_ref, "external_game_id"),
      Map.get(game_ref, :np_service_name) || Map.get(game_ref, "np_service_name")
    }
  end

  defp achievement_game_ref(game_external_id), do: {game_external_id, nil}

  defp normalize_achievement(player_trophy, detail_body, title) do
    detail_trophy =
      detail_body["trophies"]
      |> Enum.find(&(&1["trophyId"] == player_trophy["trophyId"]))
      |> case do
        nil -> %{}
        trophy -> trophy
      end

    %{
      external_achievement_id: to_string(player_trophy["trophyId"]),
      np_communication_id: to_string(title["npCommunicationId"]),
      name: detail_trophy["trophyName"] || "",
      description: detail_trophy["trophyDetail"],
      icon_image: detail_trophy["trophyIconUrl"],
      icon_locked_image: title["trophyTitleIconUrl"],
      achieved: player_trophy["earned"] == true,
      unlock_time: parse_psn_datetime(player_trophy["earnedDateTime"])
    }
  end

  defp parse_play_duration(nil), do: 0
  defp parse_play_duration(""), do: 0

  defp parse_play_duration(duration) when is_binary(duration) do
    hours = Regex.run(~r/(\d+)H/, duration) |> extract_number()
    minutes = Regex.run(~r/(\d+)M/, duration) |> extract_number()
    hours * 60 + minutes
  end

  defp extract_number(nil), do: 0
  defp extract_number([_, n]), do: String.to_integer(n)

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
