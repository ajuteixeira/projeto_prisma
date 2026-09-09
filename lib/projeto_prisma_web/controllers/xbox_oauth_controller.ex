defmodule ProjetoPrismaWeb.XboxOAuthController do
  use ProjetoPrismaWeb, :controller
  require Logger

  alias ProjetoPrisma.Accounts
  alias ProjetoPrisma.Sync.Xbox.Auth
  alias ProjetoPrismaWeb.PlatformConnect

  @state_session_key :xbox_oauth_state

  def start(conn, _params) do
    state = :crypto.strong_rand_bytes(24) |> Base.url_encode64(padding: false)

    conn
    |> put_session(@state_session_key, state)
    |> redirect(external: Auth.authorize_url(state))
  end

  def callback(conn, %{"error" => error} = params) do
    description = params["error_description"] || error

    case api_state(params) do
      {:ok, _state} ->
        redirect(conn,
          external:
            PlatformConnect.deep_link_url(
              "error",
              "xbox",
              "Falha ao autenticar com a Microsoft: #{description}"
            )
        )

      :error ->
        conn
        |> delete_session(@state_session_key)
        |> put_flash(:error, "Falha ao autenticar com a Microsoft: #{description}")
        |> redirect(to: ~p"/connect-platforms")
    end
  end

  def callback(conn, %{"code" => code, "state" => state}) do
    case api_state(state) do
      {:ok, %{profile_id: profile_id}} ->
        run_oauth_chain(conn, code, profile_id, :api)

      :error ->
        callback_web(conn, code, state)
    end
  end

  def callback(conn, params) do
    case api_state(params) do
      {:ok, _state} ->
        redirect(conn,
          external:
            PlatformConnect.deep_link_url(
              "error",
              "xbox",
              "Resposta inválida do provedor Microsoft"
            )
        )

      :error ->
        conn
        |> delete_session(@state_session_key)
        |> put_flash(:error, "Resposta inválida do provedor Microsoft")
        |> redirect(to: ~p"/connect-platforms")
    end
  end

  # Fluxo web (sessão): state aleatório guardado na sessão, profile do current_scope
  defp callback_web(conn, code, state) do
    expected_state = get_session(conn, @state_session_key)
    profile_id = current_profile_id(conn)

    cond do
      is_nil(expected_state) or expected_state != state ->
        conn
        |> delete_session(@state_session_key)
        |> put_flash(:error, "Sessão de autenticação Xbox inválida. Tente novamente.")
        |> redirect(to: ~p"/connect-platforms")

      is_nil(profile_id) ->
        conn
        |> delete_session(@state_session_key)
        |> put_flash(:error, "Não foi possível identificar o perfil atual")
        |> redirect(to: ~p"/connect-platforms")

      true ->
        run_oauth_chain(conn, code, profile_id, :web)
    end
  end

  defp api_state(%{"state" => state}), do: api_state(state)

  defp api_state(state) when is_binary(state) do
    case PlatformConnect.verify(state) do
      {:ok, %{platform: "xbox"} = data} -> {:ok, data}
      _ -> :error
    end
  end

  defp api_state(_), do: :error

  defp run_oauth_chain(conn, code, profile_id, flow) do
    with {:ok, %{access_token: access, refresh_token: refresh}} when is_binary(refresh) <-
           Auth.exchange_code(code),
         {:ok, %{token: ut}} <- Auth.user_token(access),
         {:ok, %{token: xsts, uhs: uhs, xid: xid, gamertag: gtg}} <- Auth.xsts_token(ut),
         gamertag <- gtg || maybe_fetch_gamertag(xid, uhs, xsts),
         {:ok, _account} <-
           Accounts.connect_platform_account(profile_id, "xbox", %{
             "external_user_id" => xid,
             "profile_url" => profile_url(gamertag),
             "api_key" => refresh
           }) do
      finish_success(conn, flow, "Conta Xbox vinculada com sucesso" <> gamertag_suffix(gamertag))
    else
      {:error, {:xsts_xerr, :no_xbox_account, _}} ->
        finish_error(
          conn,
          flow,
          "Esta conta Microsoft não possui um perfil Xbox Live. Crie um em xbox.com e tente novamente."
        )

      {:error, {:xsts_xerr, :child_account, _}} ->
        finish_error(
          conn,
          flow,
          "Contas infantis precisam ser adicionadas a um Grupo Familiar antes de conectar."
        )

      {:error, {:xsts_xerr, :country_banned, _}} ->
        finish_error(conn, flow, "Xbox Live não está disponível na região desta conta.")

      {:error, {:xsts_xerr, _other, _body}} ->
        finish_error(conn, flow, "Falha ao autorizar com Xbox Live (XSTS).")

      {:error, {:oauth_http_status, status, body}} ->
        Logger.error("[xbox] OAuth token exchange failed: #{status} #{inspect(body)}")
        desc = (is_map(body) && (body["error_description"] || body["error"])) || ""
        finish_error(conn, flow, "Microsoft #{status}: #{desc}")

      {:error, {:user_token, status, body}} when is_integer(status) ->
        Logger.error("[xbox] User token failed: #{status} #{inspect(body)}")
        finish_error(conn, flow, "Falha ao obter User Token Xbox (status #{status}).")

      {:error, reason} ->
        Logger.error("[xbox] OAuth chain failed: #{inspect(reason)}")
        finish_error(conn, flow, "Não foi possível concluir a vinculação com Xbox Live agora.")

      {:ok, %{refresh_token: nil}} ->
        finish_error(
          conn,
          flow,
          "Microsoft não retornou refresh_token. Verifique a permissão offline_access."
        )
    end
  end

  defp finish_success(conn, :api, _message) do
    redirect(conn, external: PlatformConnect.deep_link_url("success", "xbox"))
  end

  defp finish_success(conn, :web, message) do
    conn
    |> delete_session(@state_session_key)
    |> put_flash(:info, message)
    |> redirect(to: ~p"/connect-platforms")
  end

  defp maybe_fetch_gamertag(xid, uhs, xsts) do
    case Auth.fetch_gamertag(xid, uhs, xsts) do
      {:ok, gt} -> gt
      _ -> nil
    end
  end

  defp profile_url(nil), do: ""
  defp profile_url(gamertag), do: "https://account.xbox.com/profile?gt=#{URI.encode(gamertag)}"

  defp gamertag_suffix(nil), do: ""
  defp gamertag_suffix(gt), do: " (#{gt})"

  defp finish_error(conn, :api, message) do
    redirect(conn, external: PlatformConnect.deep_link_url("error", "xbox", message))
  end

  defp finish_error(conn, :web, message) do
    conn
    |> delete_session(@state_session_key)
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
