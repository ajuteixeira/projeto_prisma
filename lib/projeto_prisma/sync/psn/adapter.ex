defmodule ProjetoPrisma.Sync.Psn.Adapter do
  @behaviour ProjetoPrisma.Sync.PlatformBehaviour

  alias ProjetoPrisma.Sync.Psn.Client
  alias ProjetoPrisma.Utils.Psn.Psn_Auth

  @impl true
  def fetch_games(%{external_user_id: psn_id, api_key: npsso}) do
    with {:ok, auth_tokens} <- Psn_Auth.authenticate(npsso),
         access_token = auth_tokens[:access_token],
         {:ok, %{status: 200, body: trophy_body}} <- Client.get_player_trophy_titles(psn_id, access_token),
         {:ok, %{status: 200, body: owned_body}} <- Client.get_owned_games(psn_id, access_token) do

      playtime_map =
        owned_body["titles"]
        |> Enum.reduce(%{}, fn raw, acc ->
          current = Map.get(acc, raw["name"], 0)
          Map.put(acc, raw["name"], current + parse_play_duration(raw["playDuration"]))
        end)

      games =
        trophy_body["trophyTitles"]
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
  def fetch_achievements(%{external_user_id: psn_id, api_key: npsso}, _game_external_id) do
    with {:ok, auth_tokens} <- Psn_Auth.authenticate(npsso),
         access_token = auth_tokens[:access_token],
         {:ok, %{status: 200, body: titles_body}} <-
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

  defp normalize_game(raw, playtime_map) do
    %{
      external_game_id: raw["npCommunicationId"],
      name: raw["trophyTitleName"],
      cover_image: nil,
      icon_image: raw["trophyTitleIconUrl"],
      logo_image: raw["trophyTitleIconUrl"],
      playtime_minutes: Map.get(playtime_map, raw["trophyTitleName"], 0)
    }
  end

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
    hours   = Regex.run(~r/(\d+)H/, duration) |> extract_number()
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
