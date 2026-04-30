defmodule ProjetoPrisma.Utils.Psn.Psn_Profile do
  @user_legacy_base_url "https://us-prof.np.community.playstation.net/userProfile/v1/users"

  def get_profile_from_username(access_token, username) do
    fields = [
      "npId,onlineId,accountId,avatarUrls,plus,aboutMe,languagesUsed",
      "trophySummary(@default,level,progress,earnedTrophies)",
      "isOfficiallyVerified,personalDetail(@default,profilePictureUrls),personalDetailSharing,personalDetailSharingRequestMessageFlag",
      "primaryOnlineStatus,presences(@default,@titleInfo,platform,lastOnlineDate,hasBroadcastData)",
      "requestMessageFlag,blocking,friendRelation,following,consoleAvailability"
    ] |> Enum.join(",")

    url = "#{@user_legacy_base_url}/#{username}/profile2?fields=#{URI.encode(fields)}"

    case Req.get(url, headers: [{"Authorization", "Bearer #{access_token}"}]) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, %{
          account_id: get_in(body, ["profile", "accountId"]),
          online_id: get_in(body, ["profile", "onlineId"]),
          avatar_url: get_in(body, ["profile", "avatarUrls", Access.at(0), "avatarUrl"]),
          about_me: get_in(body, ["profile", "aboutMe"]),
          is_plus: get_in(body, ["profile", "plus"]) == 1,
          trophy_level: get_in(body, ["profile", "trophySummary", "level"]),
          trophy_progress: get_in(body, ["profile", "trophySummary", "progress"])
        }}

      {:ok, %{status: status, body: %{"error" => %{"message" => message}}}} ->
        {:error, "PSN erro #{status}: #{message}"}

      {:ok, %{status: status}} ->
        {:error, "PSN erro #{status}"}

      {:error, reason} ->
        {:error, "Erro na requisição: #{inspect(reason)}"}
    end
  end
end
