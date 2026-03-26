defmodule ProjetoPrismaWeb.ConnectPlatformsCardsLive do
  use ProjetoPrismaWeb, :live_view

  alias ProjetoPrisma.Accounts
  alias ProjetoPrisma.Sync.Steam.Client, as: SteamClient

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

    {:ok,
     socket
     |> assign(:profile_id, profile_id)
     |> assign(:modal_open, false)
     |> assign(:modal_platform, nil)
    |> assign(:modal_error, nil)
     |> assign(:form, to_form(%{"user_id" => "", "api_key" => ""}, as: :steam))
     |> refresh_platforms()}
  end

  @impl true
  def handle_event("platform_action", %{"platform" => "steam"}, socket) do
    platform = Enum.find(socket.assigns.platforms, &(&1.slug == "steam"))

    cond do
      is_nil(platform) ->
        {:noreply, put_flash(socket, :error, "Plataforma Steam não encontrada na tela")}

      platform.connected ->
        disconnect_steam(socket)

      true ->
        {:noreply,
         socket
         |> assign(:modal_open, true)
         |> assign(:modal_platform, platform)
         |> assign(:modal_error, nil)
         |> assign(:form, to_form(%{"user_id" => "", "api_key" => ""}, as: :steam))}
    end
  end

  def handle_event("platform_action", %{"platform" => _platform_slug}, socket) do
    {:noreply,
     put_flash(
       socket,
       :info,
       "A conexão desta plataforma será implementada por outro time. Por enquanto, somente Steam está ativa."
     )}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:modal_open, false)
     |> assign(:modal_platform, nil)
      |> assign(:modal_error, nil)
     |> assign(:form, to_form(%{"user_id" => "", "api_key" => ""}, as: :steam))}
  end

  def handle_event("save_steam_connection", %{"steam" => steam_params}, socket) do
    steam_id = String.trim(steam_params["user_id"] || "")
    api_key = String.trim(steam_params["api_key"] || "")

    cond do
      is_nil(socket.assigns.profile_id) ->
        {:noreply,
         socket
         |> assign(:modal_error, "Não foi possível identificar o perfil atual")
         |> put_flash(:error, "Não foi possível identificar o perfil atual")}

      steam_id == "" or api_key == "" ->
        {:noreply,
         socket
         |> assign(:modal_error, "Preencha Steam ID e API Key para continuar")
         |> put_flash(:error, "Preencha Steam ID e API Key para continuar")
         |> assign(:form, to_form(%{"user_id" => steam_id, "api_key" => api_key}, as: :steam))}

      not valid_steam_id?(steam_id) ->
        {:noreply,
         socket
         |> assign(:modal_error, "Steam ID inválido. Use o SteamID64 com 17 dígitos")
         |> put_flash(:error, "Steam ID inválido. Use o SteamID64 com 17 dígitos")
         |> assign(:form, to_form(%{"user_id" => steam_id, "api_key" => api_key}, as: :steam))}

      true ->
        connect_steam(socket, steam_id, api_key)
    end
  end

  defp resolve_profile_id(%{"profile_id" => profile_id}) when is_integer(profile_id),
    do: profile_id

  defp resolve_profile_id(%{"profile_id" => profile_id}) when is_binary(profile_id) do
    case Integer.parse(profile_id) do
      {id, ""} -> id
      _ -> fallback_profile_id()
    end
  end

  defp resolve_profile_id(_session), do: fallback_profile_id()

  defp fallback_profile_id do
    case Accounts.get_profile_by_username("fulano") do
      nil -> nil
      profile -> profile.id
    end
  end

  defp list_connected_slugs(nil), do: []
  defp list_connected_slugs(profile_id), do: Accounts.list_connected_platform_slugs(profile_id)

  defp refresh_platforms(socket) do
    connected_slugs = list_connected_slugs(socket.assigns.profile_id)
    assign(socket, :platforms, with_connection_status(@platforms, connected_slugs))
  end

  defp with_connection_status(platforms, connected_slugs) do
    connected_set = MapSet.new(connected_slugs)

    Enum.map(platforms, fn platform ->
      connected = MapSet.member?(connected_set, platform.slug)
      Map.put(platform, :connected, connected)
    end)
  end

  defp connect_steam(socket, steam_id, api_key) do
    with :ok <- validate_steam_credentials(steam_id, api_key),
         {:ok, _account} <-
           Accounts.connect_platform_account(socket.assigns.profile_id, "steam", %{
             "external_user_id" => steam_id,
             "profile_url" => "https://steamcommunity.com/profiles/#{steam_id}"
           }) do
      {:noreply,
       socket
       |> refresh_platforms()
       |> assign(:modal_open, false)
       |> assign(:modal_platform, nil)
      |> assign(:modal_error, nil)
       |> assign(:form, to_form(%{"user_id" => "", "api_key" => ""}, as: :steam))
       |> put_flash(:info, "Conta Steam vinculada com sucesso")}
    else
      {:error, :platform_not_found} ->
        {:noreply,
         socket
         |> assign(
           :modal_error,
           "Plataforma Steam não encontrada no banco. Rode o seed para cadastrar as plataformas."
         )
         |> put_flash(
           :error,
           "Plataforma Steam não encontrada no banco. Rode o seed para cadastrar as plataformas."
         )}

      {:error, :invalid_credentials} ->
        {:noreply,
         socket
         |> assign(:modal_error, "Falha na validação da Steam. Confira Steam ID e API Key")
         |> put_flash(:error, "Falha na validação da Steam. Confira Steam ID e API Key")
         |> assign(:form, to_form(%{"user_id" => steam_id, "api_key" => api_key}, as: :steam))}

      {:error, {:steam_http_status, status}} ->
        {:noreply,
         socket
         |> assign(
           :modal_error,
           "Steam respondeu com status #{status}. Verifique os dados e tente novamente"
         )
         |> put_flash(
           :error,
           "Steam respondeu com status #{status}. Verifique os dados e tente novamente"
         )
         |> assign(:form, to_form(%{"user_id" => steam_id, "api_key" => api_key}, as: :steam))}

      {:error, :steam_request_failed} ->
        {:noreply,
         socket
         |> assign(:modal_error, "Não foi possível validar com a API da Steam agora")
         |> put_flash(:error, "Não foi possível validar com a API da Steam agora")
         |> assign(:form, to_form(%{"user_id" => steam_id, "api_key" => api_key}, as: :steam))}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:modal_error, "Não foi possível salvar a conexão Steam")
         |> put_flash(:error, "Não foi possível salvar a conexão Steam")
         |> assign(:form, to_form(%{"user_id" => steam_id, "api_key" => api_key}, as: :steam))}
    end
  end

  defp disconnect_steam(socket) do
    case Accounts.disconnect_platform_account(socket.assigns.profile_id, "steam") do
      {:ok, _} ->
        {:noreply,
         socket
         |> refresh_platforms()
         |> put_flash(:info, "Conta Steam desvinculada")}

      {:error, :platform_not_found} ->
        {:noreply, put_flash(socket, :error, "Plataforma Steam não cadastrada")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Não foi possível desvincular a conta Steam")}
    end
  end

  defp validate_steam_credentials(steam_id, api_key) do
    case SteamClient.get_player_summary(steam_id, api_key) do
      {:ok, %{status: 200, body: %{"response" => %{"players" => players}}}}
      when is_list(players) and players != [] ->
        :ok

      {:ok, %{status: 200}} ->
        {:error, :invalid_credentials}

      {:ok, %{status: status}} ->
        {:error, {:steam_http_status, status}}

      {:error, _reason} ->
        {:error, :steam_request_failed}
    end
  end

  defp valid_steam_id?(steam_id), do: String.match?(steam_id, ~r/^\d{17}$/)

  @impl true
  def render(assigns) do
    ~H"""
    <div
      :if={@modal_open and @modal_platform}
      id="platform-modal"
      class={["connect-modal-overlay", @modal_open && "active"]}
      phx-window-keydown="close_modal"
      phx-key="escape"
    >
      <div class="connect-modal-container" phx-click-away="close_modal">
        <div class="connect-modal-header">
          <div class={["platform-icon", @modal_platform.icon_class]}>
            <i class={@modal_platform.brand_icon}></i>
          </div>
          <div>
            <h3 class="connect-modal-title">{@modal_platform.name}</h3>
            <p class="connect-modal-subtitle">Configuração de API</p>
          </div>
        </div>

        <.form for={@form} id="steam-connect-form" phx-submit="save_steam_connection">
          <div class="connect-modal-body">
            <p class="connect-modal-instruction">
              Insira seu SteamID64 (17 dígitos) e sua chave de API para validar e vincular a conta.
            </p>

            <p :if={@modal_error} class="connect-modal-error" role="alert">{@modal_error}</p>

            <div class="connect-input-group">
              <label class="connect-input-label" for="steam-user-id">Steam ID</label>
              <.input
                field={@form[:user_id]}
                id="steam-user-id"
                type="text"
                class="connect-modal-input"
                placeholder="7656119..."
              />
            </div>

            <div class="connect-input-group">
              <label class="connect-input-label" for="steam-api-key">Steam API Key</label>
              <.input
                field={@form[:api_key]}
                id="steam-api-key"
                type="password"
                class="connect-modal-input"
                placeholder="Sua chave da Steam"
              />
            </div>
          </div>

          <div class="connect-modal-actions">
            <button type="button" class="btn-cancel" phx-click="close_modal">Sair</button>
            <button type="submit" class="btn-save" phx-disable-with="Validando...">
              Vincular Conta
            </button>
          </div>
        </.form>
      </div>
    </div>

    <div class="platforms-grid" id="platforms-grid" phx-update="replace">
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
          phx-click="platform_action"
          phx-value-platform={platform.slug}
          data-confirm={
            platform.connected && platform.slug == "steam" && "Deseja desvincular sua conta Steam?"
          }
          class={[
            "connect-btn",
            platform.connected && "connected"
          ]}
          data-platform={platform.slug}
          id={"connect-btn-#{platform.slug}"}
        >
          <span :if={platform.connected}>
            <.icon name="hero-check" class="size-4 inline-block mr-2" /> Vinculado
          </span>
          <span :if={!platform.connected}>
            <i class="fas fa-link mr-2" aria-hidden="true"></i> Conectar
          </span>
        </button>
      </div>
    </div>
    """
  end
end
