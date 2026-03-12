defmodule ProjetoPrisma.Sync.Psn.Client do
  @base_url "https://m.np.playstation.com/api/"
  @other_url "https://us-prof.np.community.playstation.net/"

  def get_owned_games(psn_id, access_token) do
    Req.get("#{@base_url}/gamelist/v2/users/#{psn_id}/titles",
      headers: [
        Authorization: "Bearer #{access_token}"
      ]
    )
  end

  def get_player_achievements(psn_id, access_token) do
    Req.get("#{@base_url}/trophy/v1/users/#{psn_id}/trophyTitles",
      headers: [
        Authorization: "Bearer #{access_token}"
      ]
    )
  end

  def get_detail_achievements(psn_id, npTitleId, access_token) do
    Req.get("#{@base_url}/trophy/v1/users/#{psn_id}/titles/trophyTitles",
      params: [
        npTitleIds: npTitleId,
      ],
      headers: [
        Authorization: "Bearer #{access_token}"
      ]
    )
  end

  def get_player_profile(psn_id, access_token) do
    Req.get("#{@other_url}/userProfile/v1/users/#{psn_id}/profile2",
      headers: [
        Authorization: "Bearer #{access_token}"
      ]
    )
  end

end
