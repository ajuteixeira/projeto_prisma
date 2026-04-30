defmodule ProjetoPrismaWeb.ProfileStatsLive do
  use ProjetoPrismaWeb, :live_view

  alias ProjetoPrisma.Accounts
  alias ProjetoPrisma.Accounts.ProfileDashboard
  alias ProjetoPrisma.Accounts.Scope

  @default_stats %{total_achievements: 0, avg_completion: 0, perfect_games: 0}

  @impl true
  def mount(_params, session, socket) do
    current_scope = Accounts.resolve_scope_from_session(session)
    profile = ProfileDashboard.profile_for_user(scope_user_id(current_scope))

    stats =
      if profile,
        do: ProfileDashboard.stats(profile.id),
        else: @default_stats

    {:ok, assign(socket, :stats, stats)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!--
      Este LiveView renderiza os 3 stat-cards como fragmento.
      O grid (grid-cols-3) fica no pai (profile_html.heex), portanto cada
      live_render() ocupa naturalmente uma coluna — sem conflito de flex/grid.
    --%>

    <%!-- Conquistas --%>
    <div class="stat-card card p-6 text-center justify-center rounded-2xl">
      <div class="stat-inner">
        <i class="fas fa-trophy trophy-icon stat-icon"></i>
        <div class="stat-content">
          <div class="stat-title text-gray-400 text-sm uppercase tracking-wide">Conquistas</div>
          <h3 class="stat-value text-4xl font-bold mb-1">{format_number(@stats.total_achievements)}</h3>
        </div>
      </div>
    </div>

    <%!-- Média de Conclusão --%>
    <div class="stat-card card p-6 text-center has-progress justify-center rounded-2xl">
      <div class="stat-inner">
        <i class="fas fa-gamepad controller-icon stat-icon"></i>
        <div class="stat-content">
          <div class="stat-title text-gray-400 text-sm uppercase tracking-wide">Média de Conclusão</div>
          <div class="stat-value flex items-center justify-start md:justify-center gap-2 mb-1">
            <h3 class="text-4xl font-bold gradient-text">{display_avg(@stats.avg_completion)}</h3>
            <span class="text-2xl font-bold text-gray-400">%</span>
          </div>
        </div>
      </div>
      <div class="stat-progress mt-3 w-full">
        <div class="progress-bar bg-gray-700 mx-auto" style="width: 80%;">
          <div
            class="progress-fill bg-gradient-to-r from-blue-500 to-blue-600"
            style={"width: #{progress_width(@stats.avg_completion)}%;"}
          ></div>
        </div>
      </div>
    </div>

    <%!-- Jogos Perfeitos --%>
    <div class="stat-card card p-6 text-center justify-center rounded-2xl">
      <div class="stat-inner">
        <i class="fas fa-users users-icon stat-icon m-auto"></i>
        <div class="stat-content">
          <div class="stat-title text-gray-400 text-sm uppercase tracking-wide">Jogos Perfeitos</div>
          <h3 class="stat-value text-4xl font-bold mb-1">{format_number(@stats.perfect_games)}</h3>
        </div>
      </div>
    </div>
    """
  end

  # ── helpers ──────────────────────────────────────────────────────────────────

  defp format_number(value) when is_integer(value), do: Integer.to_string(value)
  defp format_number(_), do: "0"

  defp display_avg(value) when is_number(value), do: trunc(value)
  defp display_avg(_), do: 0

  defp progress_width(value) when is_number(value), do: value |> max(0) |> min(100)
  defp progress_width(_), do: 0

  defp scope_user_id(%Scope{user: %{id: id}}) when is_integer(id), do: id
  defp scope_user_id(_), do: nil
end
