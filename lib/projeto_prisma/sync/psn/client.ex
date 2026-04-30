defmodule ProjetoPrisma.Sync.Psn.Client do
  @base_url "https://m.np.playstation.com/api/"
  @other_url "https://us-prof.np.community.playstation.net/"

  alias ProjetoPrisma.Utils.Psn.Psn_Auth

  def get_owned_games(psn_id, access_token) do
    Req.get("#{@base_url}/gamelist/v2/users/#{psn_id}/titles",
      headers: [
        Authorization: "Bearer #{access_token}"
      ]
    )
  end

  def get_player_trophy_titles(psn_id, access_token) do
    Req.get("#{@base_url}/trophy/v1/users/#{psn_id}/trophyTitles",
      headers: [
        Authorization: "Bearer #{access_token}"
      ]
    )
  end

  def get_detail_achievement(npCommunicationId, access_token) do
    Req.get(
      "#{@base_url}/trophy/v1/npCommunicationIds/#{npCommunicationId}/trophyGroups/all/trophies",
      headers: [
        Authorization: "Bearer #{access_token}"
      ]
    )
  end

  def get_player_achievement(psn_id, npCommunicationId, access_token) do
    Req.get(
      "#{@base_url}/trophy/v1/users/#{psn_id}/npCommunicationIds/#{npCommunicationId}/trophyGroups/all/trophies",
      headers: [
        Authorization: "Bearer #{access_token}"
      ]
    )
  end

  def get_player_profile(psn_id, npsso) do
    case Psn_Auth.authenticate(npsso) do
      {:ok, auth_tokens} ->
        access_token = auth_tokens[:access_token]
        Req.get("#{@other_url}/userProfile/v1/users/#{psn_id}/profile2",
          headers: [
            Authorization: "Bearer #{access_token}"
          ]
        )
    end
  end
end
