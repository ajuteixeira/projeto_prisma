defmodule ProjetoPrisma.Sync.RetroAchievements.Client do
  @default_url "https://retroachievements.org/API"

  def get_owned_games(retroach_id, api_key) do
    Req.get("#{@default_url}/API_GetUserCompletedGames.php",
      params: [
        y: api_key,
        u: retroach_id
      ]
    )
  end

  def get_player_achievements(retroach_id, api_key, game_external_id) do
    Req.get("#{@default_url}/API_GetGameInfoAndUserProgress.php",
      params: [
        y: api_key,
        u: retroach_id,
        g: game_external_id,
        a: 1
      ]
    )
  end

  def get_detail_achievements(game_id, api_key) do
    Req.get("#{@default_url}/API_GetGameExtended.php",
      params: [
        y: api_key,
        i: game_id
      ]
    )
  end

  def get_player_profile(retroach_id, api_key) do
    Req.get("#{@default_url}/API_GetUserProfile.php",
      params: [
        y: api_key,
        u: retroach_id
      ]
    )
  end
end
