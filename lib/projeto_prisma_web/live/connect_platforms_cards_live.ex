defmodule ProjetoPrismaWeb.ConnectPlatformsCardsLive do
  use ProjetoPrismaWeb, :live_view

  alias ProjetoPrisma.Accounts

  @platforms [
    %{
      slug: "steam",
      name: "Steam",
      description: "Vincule sua biblioteca Steam",
      brand_icon: "fab fa-steam",
      icon_class: "icon-steam",
      connected: false
    },
    %{
      slug: "playstation",
      name: "PlayStation Network",
      description: "Conecte sua conta PSN",
      brand_icon: "fab fa-playstation",
      icon_class: "icon-playstation",
      connected: false
    },
    %{
      slug: "xbox",
      name: "Xbox Live",
      description: "Conecte sua conta Xbox",
      brand_icon: "fab fa-xbox",
      icon_class: "icon-xbox",
      connected: false
    },
    %{
      slug: "retroachievements",
      name: "RetroAchievements",
      description: "Vincule RetroAchievements",
      brand_icon: "fas fa-trophy",
      icon_class: "icon-retro",
      connected: false
    }
  ]

  @impl true
  def mount(_params, session, socket) do
    profile_id = resolve_profile_id(session)
    connected_slugs = list_connected_slugs(profile_id)

    {:ok,
     socket
     |> assign(:profile_id, profile_id)
     |> assign(:platforms, with_connection_status(@platforms, connected_slugs))}
  end

  defp resolve_profile_id(%{"profile_id" => profile_id}) when is_integer(profile_id), do: profile_id

  defp resolve_profile_id(%{"profile_id" => profile_id}) when is_binary(profile_id) do
    case Integer.parse(profile_id) do
      {id, ""} -> id
      _ -> fallback_profile_id()
    end
  end

  defp resolve_profile_id(_session), do: fallback_profile_id()

  defp fallback_profile_id do
    case Accounts.get_or_create_profile(%{username: "demo"}) do
      {:ok, profile} -> profile.id
      {:error, _changeset} -> nil
    end
  end

  defp list_connected_slugs(nil), do: []
  defp list_connected_slugs(profile_id), do: Accounts.list_connected_platform_slugs(profile_id)

  defp with_connection_status(platforms, connected_slugs) do
    connected_set = MapSet.new(connected_slugs)

    Enum.map(platforms, fn platform ->
      connected = MapSet.member?(connected_set, platform.slug)
      Map.put(platform, :connected, connected)
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="platforms-grid" id="platforms-grid">
      <div :for={platform <- @platforms} class="platform-card" id={"platform-card-#{platform.slug}"}>
        <div class="platform-header">
          <div class={["platform-icon", platform.icon_class]}>
            <i class={[platform.brand_icon, "platform-fa"]}></i>
          </div>
          <div class="platform-info">
            <h3 class="platform-name">{platform.name}</h3>
            <p class="platform-description">{platform.description}</p>
          </div>
        </div>

        <button
          type="button"
          class={[
            "connect-btn",
            platform.connected && "connected"
          ]}
          data-platform={platform.slug}
          id={"connect-btn-#{platform.slug}"}
        >
          <span :if={platform.connected}>
            <.icon name="hero-check" class="size-4 inline-block mr-2" />
            Vinculado
          </span>
          <span :if={!platform.connected}>
            <i class="fas fa-link mr-2" aria-hidden="true"></i>
            Conectar
          </span>
        </button>
      </div>
    </div>
    """
  end
end
