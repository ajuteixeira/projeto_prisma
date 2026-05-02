defmodule ProjetoPrismaWeb.ProfileGamesLive do
  use ProjetoPrismaWeb, :live_view

  alias ProjetoPrisma.Accounts
  alias ProjetoPrisma.Accounts.ProfileDashboard
  alias ProjetoPrisma.Accounts.Scope

  @page_size 10

  @impl true
  def mount(_params, session, socket) do
    current_scope = Accounts.resolve_scope_from_session(session)
    profile = ProfileDashboard.profile_for_user(scope_user_id(current_scope))

    socket =
      socket
      |> assign(:profile_id, profile && profile.id)
      |> assign(:current_page, 1)
      |> assign(:sort_order, :desc)
      |> assign(:games_empty?, true)
      |> assign(:has_next_page?, false)
      |> assign(:has_previous_page?, false)
      |> stream_configure(:games, dom_id: &"profile-game-#{&1.profile_game_id}")
      |> stream(:games, [], reset: true)
      |> load_page(1)

    {:ok, socket}
  end

  @impl true
  def handle_event("next_page", _params, socket) do
    socket =
      if socket.assigns.has_next_page? do
        load_page(socket, socket.assigns.current_page + 1)
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("previous_page", _params, socket) do
    socket =
      if socket.assigns.has_previous_page? do
        load_page(socket, socket.assigns.current_page - 1)
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_last_played_order", _params, socket) do
    socket =
      socket
      |> assign(:sort_order, toggle_sort_order(socket.assigns.sort_order))
      |> load_page(1)

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-gray-800/80 border border-gray-700 p-6 rounded-2xl w-full">
      <div class="flex items-center justify-between mb-6">
        <h2 class="text-2xl font-bold">Jogos</h2>
      </div>

      <%!-- Cabeçalho desktop --%>
      <div class="hidden md:grid grid-cols-12 gap-4 px-4 py-3 border-b border-gray-700">
        <div class="col-span-3 table-header">Jogo</div>
        <div class="col-span-2 table-header">Conclusão</div>
        <div class="col-span-1 table-header">Conquistas</div>
        <div class="col-span-2 table-header">Tempo de Jogo</div>
        <div class="col-span-2 table-header">Último Desbloqueio</div>
        <div class="col-span-1 table-header">
          <button
            id="profile-games-sort-last-played"
            type="button"
            phx-click="toggle_last_played_order"
            class="inline-flex items-center gap-1 text-left transition hover:text-white"
          >
            <span>Última Vez Jogado</span>
            <.icon name={sort_icon_name(@sort_order)} class="size-4" />
          </button>
        </div>
        <div class="col-span-1 table-header">Plataforma</div>
      </div>

      <div id="profile-games-list" class="space-y-2 mt-2" phx-update="stream">
        <div
          :if={@games_empty?}
          id="profile-games-empty"
          class="rounded-2xl border border-dashed border-gray-700 bg-gray-900/40 px-5 py-10 text-center"
        >
          <div class="mx-auto flex max-w-md flex-col items-center gap-3">
            <div class="rounded-full border border-emerald-500/30 bg-emerald-500/10 p-3">
              <.icon name="hero-information-circle" class="size-6 text-emerald-300" />
            </div>
            <div>
              <p class="text-lg font-semibold text-white">Sem jogos sincronizados</p>
              <p class="mt-1 text-sm text-gray-400">
                Conecte uma plataforma para começar a preencher seu histórico de jogos.
              </p>
            </div>
          </div>
        </div>

        <div :for={{dom_id, game} <- @streams.games} id={dom_id}>
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
                    <.icon name="hero-trophy" class="size-4 text-yellow-400" />
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
                    >
                    </div>
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
                <div class="text-xs text-gray-500">
                  Total {format_playtime(game.playtime_minutes)}
                </div>
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
                >
                </div>
              </div>
              <span class="text-xs text-gray-400 mt-1 block">{game.completion_percent}%</span>
            </div>
            <div class="col-span-6 md:col-span-1">
              <span class="text-sm">
                <.icon name="hero-trophy" class="mr-1 inline-block size-4 text-yellow-500" />
                {game.unlocked_achievements} / {game.total_achievements}
              </span>
            </div>
            <div class="col-span-6 md:col-span-2">
              <div class="text-sm">
                <div>{format_playtime(game.playtime_minutes)}</div>
                <div class="text-gray-400 text-xs">
                  Total {format_playtime(game.playtime_minutes)}
                </div>
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

      <div
        :if={!@games_empty?}
        id="profile-games-pagination"
        class="mt-6 flex flex-col gap-3 border-t border-gray-700/80 pt-5 sm:flex-row sm:items-center sm:justify-between"
      >
        <div class="flex items-center justify-end gap-2">
          <button
            id="profile-games-previous-page"
            type="button"
            phx-click="previous_page"
            disabled={!@has_previous_page?}
            class={[
              "inline-flex items-center gap-2 rounded-xl border px-4 py-2 text-sm font-medium transition",
              @has_previous_page? &&
                "border-gray-600 bg-gray-800/80 text-white hover:border-gray-500 hover:bg-gray-700/80",
              !@has_previous_page? && "cursor-not-allowed border-gray-800 bg-gray-900/70 text-gray-500"
            ]}
          >
            <.icon name="hero-chevron-left" class="size-4" />
            Anterior
          </button>

          <button
            id="profile-games-next-page"
            type="button"
            phx-click="next_page"
            disabled={!@has_next_page?}
            class={[
              "inline-flex items-center gap-2 rounded-xl border px-4 py-2 text-sm font-medium transition",
              @has_next_page? &&
                "border-emerald-500/40 bg-emerald-500/10 text-emerald-100 hover:border-emerald-400/70 hover:bg-emerald-500/15",
              !@has_next_page? &&
                "cursor-not-allowed border-gray-800 bg-gray-900/70 text-gray-500"
            ]}
          >
            Próxima
            <.icon name="hero-chevron-right" class="size-4" />
          </button>
        </div>
      </div>
    </div>
    """
  end

  # ── helpers ──────────────────────────────────────────────────────────────────

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

  defp load_page(socket, page) when page > 0 do
    profile_id = socket.assigns.profile_id
    offset = (page - 1) * @page_size
    sort_order = socket.assigns.sort_order

    games =
      if is_integer(profile_id) do
        ProfileDashboard.list_games(profile_id, @page_size + 1,
          offset: offset,
          sort_order: sort_order
        )
      else
        []
      end

    {page_games, has_next_page?} = page_entries(games)

    if page > 1 and page_games == [] do
      load_page(socket, page - 1)
    else
      socket
      |> assign(:current_page, page)
      |> assign(:games_empty?, page_games == [])
      |> assign(:has_next_page?, has_next_page?)
      |> assign(:has_previous_page?, page > 1)
      |> stream(:games, page_games, reset: true)
    end
  end

  defp page_entries(games) do
    case Enum.split(games, @page_size) do
      {page_games, []} -> {page_games, false}
      {page_games, _rest} -> {page_games, true}
    end
  end

  defp toggle_sort_order(:asc), do: :desc
  defp toggle_sort_order(_sort_order), do: :asc

  defp sort_icon_name(:asc), do: "hero-chevron-up"
  defp sort_icon_name(_sort_order), do: "hero-chevron-down"

  defp scope_user_id(%Scope{user: %{id: id}}) when is_integer(id), do: id
  defp scope_user_id(_), do: nil
end
