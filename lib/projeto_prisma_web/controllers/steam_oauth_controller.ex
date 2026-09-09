defmodule ProjetoPrismaWeb.SteamOAuthController do
  use ProjetoPrismaWeb, :controller
  require Logger

  alias ProjetoPrisma.Accounts
  alias ProjetoPrisma.Sync.Steam.OpenID
  alias ProjetoPrismaWeb.PlatformConnect

  @claimed_id_regex ~r|^https?://steamcommunity\.com/openid/id/(\d{17})$|

  def start(conn, params) do
    api_key = params |> Map.get("api_key", "") |> to_string() |> String.trim()

    if api_key == "" do
      conn
      |> put_flash(:error, "Informe sua Steam Web API Key para continuar")
      |> redirect(to: ~p"/connect-platforms")
    else
      return_to = url(~p"/auth/steam/callback")
      realm = ProjetoPrismaWeb.Endpoint.url()

      conn
      |> put_session(:steam_pending_api_key, api_key)
      |> redirect(external: OpenID.authorize_url(return_to, realm))
    end
  end

  def callback(conn, %{"openid.mode" => "cancel"} = params) do
    case api_state(params) do
      {:ok, _state} ->
        redirect(conn,
          external:
            PlatformConnect.deep_link_url("error", "steam", "Autenticação com a Steam cancelada")
        )

      :error ->
        conn
        |> delete_session(:steam_pending_api_key)
        |> put_flash(:error, "Autenticação com a Steam cancelada")
        |> redirect(to: ~p"/connect-platforms")
    end
  end

  def callback(conn, %{"openid.mode" => "error"} = params) do
    Logger.error("[steam] OpenID error: #{inspect(params)}")

    case api_state(params) do
      {:ok, _state} ->
        redirect(conn,
          external:
            PlatformConnect.deep_link_url(
              "error",
              "steam",
              "Steam retornou um erro durante a autenticação"
            )
        )

      :error ->
        conn
        |> delete_session(:steam_pending_api_key)
        |> put_flash(:error, "Steam retornou um erro durante a autenticação")
        |> redirect(to: ~p"/connect-platforms")
    end
  end

  def callback(conn, %{"openid.mode" => "id_res"} = params) do
    case api_state(params) do
      {:ok, %{profile_id: profile_id, api_key: api_key}} ->
        verify_and_connect_api(conn, params, profile_id, api_key)

      :error ->
        callback_web(conn, params)
    end
  end

  def callback(conn, params) do
    case api_state(params) do
      {:ok, _state} ->
        redirect(conn,
          external: PlatformConnect.deep_link_url("error", "steam", "Resposta inválida da Steam")
        )

      :error ->
        conn
        |> delete_session(:steam_pending_api_key)
        |> put_flash(:error, "Resposta inválida da Steam")
        |> redirect(to: ~p"/connect-platforms")
    end
  end

  # Fluxo web (sessão): profile vem do current_scope, api_key da sessão
  defp callback_web(conn, params) do
    profile_id = current_profile_id(conn)
    api_key = get_session(conn, :steam_pending_api_key)

    cond do
      is_nil(profile_id) ->
        conn
        |> delete_session(:steam_pending_api_key)
        |> put_flash(:error, "Não foi possível identificar o perfil atual")
        |> redirect(to: ~p"/connect-platforms")

      is_nil(api_key) or api_key == "" ->
        conn
        |> delete_session(:steam_pending_api_key)
        |> put_flash(:error, "Chave da API Steam ausente. Tente novamente.")
        |> redirect(to: ~p"/connect-platforms")

      true ->
        verify_and_connect(conn, params, profile_id, api_key)
    end
  end

  # Fluxo API (mobile): profile e api_key vêm do state assinado
  defp verify_and_connect_api(conn, params, profile_id, api_key) do
    with {:ok, steam_id} <- extract_steam_id(params["openid.claimed_id"]),
         :ok <- OpenID.verify_assertion(params),
         {:ok, _account} <-
           Accounts.connect_platform_account(profile_id, "steam", %{
             "external_user_id" => steam_id,
             "profile_url" => "https://steamcommunity.com/profiles/#{steam_id}",
             "api_key" => api_key
           }) do
      redirect(conn, external: PlatformConnect.deep_link_url("success", "steam"))
    else
      {:error, reason} ->
        Logger.error("[steam] API OpenID flow failed: #{inspect(reason)}")

        redirect(conn,
          external:
            PlatformConnect.deep_link_url(
              "error",
              "steam",
              "Não foi possível concluir a vinculação com a Steam"
            )
        )
    end
  end

  defp api_state(%{"state" => state}) when is_binary(state) do
    case PlatformConnect.verify(state) do
      {:ok, %{platform: "steam"} = data} -> {:ok, data}
      _ -> :error
    end
  end

  defp api_state(_params), do: :error

  defp verify_and_connect(conn, params, profile_id, api_key) do
    with {:ok, steam_id} <- extract_steam_id(params["openid.claimed_id"]),
         :ok <- OpenID.verify_assertion(params),
         {:ok, _account} <-
           Accounts.connect_platform_account(profile_id, "steam", %{
             "external_user_id" => steam_id,
             "profile_url" => "https://steamcommunity.com/profiles/#{steam_id}",
             "api_key" => api_key
           }) do
      conn
      |> delete_session(:steam_pending_api_key)
      |> put_flash(:info, "Conta Steam vinculada com sucesso")
      |> redirect(to: ~p"/connect-platforms")
    else
      {:error, :invalid_claimed_id} ->
        finish_error(conn, "claimed_id inválido na resposta da Steam")

      {:error, :assertion_invalid} ->
        finish_error(conn, "Falha ao verificar a autenticação com a Steam")

      {:error, {:verify_http_status, status}} ->
        finish_error(conn, "Steam respondeu com status #{status} ao verificar a autenticação")

      {:error, :verify_request_failed} ->
        finish_error(conn, "Não foi possível verificar a autenticação com a Steam agora")

      {:error, reason} ->
        Logger.error("[steam] OpenID flow failed: #{inspect(reason)}")
        finish_error(conn, "Não foi possível concluir a vinculação com a Steam agora")
    end
  end

  defp extract_steam_id(claimed_id) when is_binary(claimed_id) do
    case Regex.run(@claimed_id_regex, claimed_id) do
      [_, steam_id] -> {:ok, steam_id}
      _ -> {:error, :invalid_claimed_id}
    end
  end

  defp extract_steam_id(_), do: {:error, :invalid_claimed_id}

  defp finish_error(conn, message) do
    conn
    |> delete_session(:steam_pending_api_key)
    |> put_flash(:error, message)
    |> redirect(to: ~p"/connect-platforms")
  end

  defp current_profile_id(conn) do
    with %{} = scope <- conn.assigns[:current_scope],
         %{} = profile <- Accounts.get_profile_with_user(scope) do
      profile.id
    else
      _ -> nil
    end
  end
end
