defmodule ProjetoPrismaWeb.ProfilePlatformDistributionLive do
  use ProjetoPrismaWeb, :live_view

  alias ProjetoPrisma.Accounts
  alias ProjetoPrisma.Accounts.ProfileDashboard
  alias ProjetoPrisma.Accounts.Scope

  @platforms [
    %{slug: "playstation",      name: "PlayStation",       color: "#0070CC", icon: "fab fa-playstation"},
    %{slug: "xbox",             name: "Xbox",              color: "#107C10", icon: "fab fa-xbox"},
    %{slug: "steam",            name: "Steam",             color: "#66c0f4", icon: "fab fa-steam"},
    %{slug: "retroachievements",name: "RetroAchievements", color: "#D4A017", icon: "fas fa-gamepad"}
  ]

  @impl true
  def mount(_params, session, socket) do
    current_scope = Accounts.resolve_scope_from_session(session)
    profile = ProfileDashboard.profile_for_user(scope_user_id(current_scope))

    distribution =
      if profile,
        do: ProfileDashboard.platform_distribution(profile.id),
        else: []

    {:ok, assign(socket, :distribution, distribution)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-gray-800/80 p-4 rounded-2xl border border-gray-700 w-full">
      <div class="flex items-center justify-between mb-2 rounded-2xl">
        <h3 class="text-sm font-semibold text-gray-400 uppercase tracking-wide">
          Distribuição de Troféus por Plataforma
        </h3>
      </div>

      <%!-- Barra de progresso segmentada --%>
      <div class="flex h-3 rounded-full overflow-hidden">
        <div
          :for={item <- normalized_distribution(@distribution)}
          class="transition-all duration-500 hover:opacity-80 cursor-pointer"
          style={"width: #{item.percentage}%; background-color: #{item.color};"}
          title={"#{item.name} - #{display_percent(item.percentage)}%"}
        ></div>
      </div>

      <%!-- Legenda desktop --%>
      <div class="hidden md:grid grid-cols-2 md:grid-cols-4 gap-4 mt-4">
        <div :for={item <- normalized_distribution(@distribution)} class="flex items-center space-x-2">
          <div class="w-3 h-3 rounded-full" style={"background-color: #{item.color};"}></div>
          <span class="text-xs text-gray-400">
            {item.name} <strong class="text-white">{display_percent(item.percentage)}%</strong>
          </span>
        </div>
      </div>

      <%!-- Ícones mobile --%>
      <div class="platform-list flex items-center justify-between gap-4 mt-4 flex-wrap md:hidden">
        <div
          :for={item <- normalized_distribution(@distribution)}
          class="platform-item flex flex-col items-center text-center"
        >
          <div
            class="platform-circle inline-flex items-center justify-center"
            style={"background-color: #{item.color};"}
          >
            <i class={item.icon} aria-hidden="true"></i>
          </div>
          <span class="platform-percent text-xs text-gray-400 mt-2">
            <strong class="text-white">{display_percent(item.percentage)}%</strong>
          </span>
        </div>
      </div>
    </div>
    """
  end

  # ── helpers ──────────────────────────────────────────────────────────────────

  defp normalized_distribution(items) do
    by_slug = Map.new(items, &{&1.slug, &1})

    Enum.map(@platforms, fn platform ->
      percentage =
        case Map.get(by_slug, platform.slug) do
          nil -> 0
          item -> item.percentage
        end

      Map.put(platform, :percentage, percentage)
    end)
  end

  defp display_percent(v) when is_float(v),
    do: if(v == Float.floor(v), do: trunc(v), else: v)

  defp display_percent(v) when is_integer(v), do: v
  defp display_percent(_), do: 0

  defp scope_user_id(%Scope{user: %{id: id}}) when is_integer(id), do: id
  defp scope_user_id(_), do: nil
end
