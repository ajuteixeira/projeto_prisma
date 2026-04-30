defmodule ProjetoPrismaWeb.ProfileRecentGamesLive do
  use ProjetoPrismaWeb, :live_view

  alias ProjetoPrisma.Accounts
  alias ProjetoPrisma.Accounts.ProfileDashboard
  alias ProjetoPrisma.Accounts.Scope

  @empty_game %{
    game_name: "Sem jogos sincronizados",
    game_cover_image: nil,
    unlocked_achievements: 0,
    total_achievements: 0,
    completion_percent: 0,
    playtime_minutes: 0,
    last_unlock_time: nil,
    last_played: nil,
    platform_name: "-"
  }

  @impl true
  def mount(_params, session, socket) do
    current_scope = Accounts.resolve_scope_from_session(session)
    profile = ProfileDashboard.profile_for_user(scope_user_id(current_scope))

    games =
      if profile,
        do: ProfileDashboard.recent_games(profile.id, 10),
        else: []

    {:ok, assign(socket, :games, games)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-gray-800/80 border border-gray-700 p-6 rounded-2xl w-full">
      <div class="flex items-center justify-between mb-6">
        <h2 class="text-2xl font-bold">Jogos Recentes</h2>
      </div>

      <%!-- Cabeçalho desktop --%>
      <div class="hidden md:grid grid-cols-12 gap-4 px-4 py-3 border-b border-gray-700">
        <div class="col-span-3 table-header">Jogo</div>
        <div class="col-span-2 table-header">Conclusão</div>
        <div class="col-span-1 table-header">Conquistas</div>
        <div class="col-span-2 table-header">Tempo de Jogo</div>
        <div class="col-span-2 table-header">Último Desbloqueio</div>
        <div class="col-span-1 table-header">Última Vez Jogado</div>
        <div class="col-span-1 table-header">Plataforma</div>
      </div>

      <div class="space-y-2 mt-2">
        <div :for={game <- listed_games(@games)}>

          <%!-- Card mobile --%>
          <div class="mobile-game-card md:hidden p-3 rounded-lg mb-2 bg-transparent">
            <div class="mobile-top-row flex items-center gap-3">
              <img
                src={cover_image(game)}
                alt={game.game_name}
                class="w-12 h-12 rounded object-cover"
              />
              <div class="mobile-meta flex-1">
                <div class="flex items-center justify-between">
                  <div class="mobile-title font-semibold text-base">{game.game_name}</div>
                  <div class="mobile-trophies text-sm flex items-center gap-2">
                    <i class="fas fa-trophy text-yellow-400"></i>
                    <span class="font-semibold">
                      {game.unlocked_achievements} / {game.total_achievements}
                    </span>
                  </div>
                </div>
                <div class="mt-2">
                  <div class="progress-bar bg-gray-700 rounded-full overflow-hidden h-2">
                    <div
                      class="progress-fill bg-emerald-500"
                      style={"width: #{game.completion_percent}%;"}
                    ></div>
                  </div>
                  <div class="flex items-center justify-between text-xs text-gray-400 mt-1">
                    <span>{game.completion_percent}%</span>
                    <span>{format_date(game.last_played)}</span>
                  </div>
                </div>
              </div>
            </div>
            <div class="mobile-meta-extra mt-2 text-xs text-gray-400 flex items-center justify-between gap-3">
              <div>
                <div class="font-semibold">{format_playtime(game.playtime_minutes)}</div>
                <div class="text-xs text-gray-500">Total {format_playtime(game.playtime_minutes)}</div>
              </div>
              <div class="flex items-center space-x-2">
                <span class="platform-badge inline-block px-3 py-1 rounded text-xs bg-blue-700/30">
                  {game.platform_name}
                </span>
              </div>
            </div>
          </div>

          <%!-- Linha desktop --%>
          <div class="game-row hidden md:grid md:grid-cols-12 gap-4 p-4 rounded-lg items-center">
            <div class="col-span-12 md:col-span-3 flex items-center space-x-3">
              <img src={cover_image(game)} alt={game.game_name} class="game-thumbnail" />
              <span class="font-semibold">{game.game_name}</span>
            </div>
            <div class="col-span-6 md:col-span-2">
              <div class="progress-bar bg-gray-700">
                <div
                  class="progress-fill bg-gradient-to-r from-green-500 to-emerald-600"
                  style={"width: #{game.completion_percent}%;"}
                ></div>
              </div>
              <span class="text-xs text-gray-400 mt-1 block">{game.completion_percent}%</span>
            </div>
            <div class="col-span-6 md:col-span-1">
              <span class="text-sm">
                <i class="fas fa-trophy text-yellow-500 mr-1"></i>
                {game.unlocked_achievements} / {game.total_achievements}
              </span>
            </div>
            <div class="col-span-6 md:col-span-2">
              <div class="text-sm">
                <div>{format_playtime(game.playtime_minutes)}</div>
                <div class="text-gray-400 text-xs">Total {format_playtime(game.playtime_minutes)}</div>
              </div>
            </div>
            <div class="col-span-6 md:col-span-2">
              <span class="text-sm text-gray-400">{format_datetime(game.last_unlock_time)}</span>
            </div>
            <div class="col-span-6 md:col-span-1">
              <span class="text-sm text-gray-400">{format_date(game.last_played)}</span>
            </div>
            <div class="col-span-6 md:col-span-1">
              <span class="platform-badge">{game.platform_name}</span>
            </div>
          </div>

        </div>
      </div>
    </div>
    """
  end

  # ── helpers ──────────────────────────────────────────────────────────────────

  defp listed_games([]), do: [@empty_game]
  defp listed_games(games), do: games

  defp cover_image(%{game_cover_image: img}) when is_binary(img) and img != "", do: img
  defp cover_image(%{game_icon_image: img}) when is_binary(img) and img != "", do: img
  defp cover_image(_), do: "https://placehold.co/96x96/1e293b/e2e8f0?text=Game"

  defp format_playtime(minutes) when is_integer(minutes) and minutes >= 0 do
    hours = div(minutes, 60)
    mins = rem(minutes, 60)

    cond do
      hours > 0 and mins > 0 -> "#{hours}h #{mins}m"
      hours > 0 -> "#{hours}h"
      true -> "#{mins}m"
    end
  end

  defp format_playtime(_), do: "0h"

  defp format_datetime(%NaiveDateTime{} = dt) do
    date = dt |> NaiveDateTime.to_date() |> Date.to_iso8601()
    time = dt |> NaiveDateTime.to_time() |> Time.to_iso8601()
    "#{date} #{time}"
  end

  defp format_datetime(_), do: "-"

  defp format_date(%NaiveDateTime{} = dt),
    do: dt |> NaiveDateTime.to_date() |> Date.to_iso8601()

  defp format_date(_), do: "-"

  defp scope_user_id(%Scope{user: %{id: id}}) when is_integer(id), do: id
  defp scope_user_id(_), do: nil
end
