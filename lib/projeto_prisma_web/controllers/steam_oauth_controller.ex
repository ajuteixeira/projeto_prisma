defmodule ProjetoPrismaWeb.SteamOAuthController do
  use ProjetoPrismaWeb, :controller
  require Logger

  alias ProjetoPrisma.Accounts

  @openid_endpoint "https://steamcommunity.com/openid/login"
  @openid_ns "http://specs.openid.net/auth/2.0"
  @identifier_select "http://specs.openid.net/auth/2.0/identifier_select"
  @claimed_id_regex ~r|^https?://steamcommunity\.com/openid/id/(\d{17})$|

  def start(conn, _params) do
    return_to = url(~p"/auth/steam/callback")
    realm = ProjetoPrismaWeb.Endpoint.url()

    query =
      URI.encode_query(%{
        "openid.ns" => @openid_ns,
        "openid.mode" => "checkid_setup",
        "openid.return_to" => return_to,
        "openid.realm" => realm,
        "openid.identity" => @identifier_select,
        "openid.claimed_id" => @identifier_select
      })

    redirect(conn, external: @openid_endpoint <> "?" <> query)
  end

  def callback(conn, %{"openid.mode" => "cancel"}) do
    conn
    |> put_flash(:error, "Autenticação com a Steam cancelada")
    |> redirect(to: ~p"/connect-platforms")
  end

  def callback(conn, %{"openid.mode" => "error"} = params) do
    Logger.error("[steam] OpenID error: #{inspect(params)}")

    conn
    |> put_flash(:error, "Steam retornou um erro durante a autenticação")
    |> redirect(to: ~p"/connect-platforms")
  end

  def callback(conn, %{"openid.mode" => "id_res"} = params) do
    profile_id = current_profile_id(conn)
    api_key = System.get_env("STEAM_API_KEY")

    cond do
      is_nil(profile_id) ->
        conn
        |> put_flash(:error, "Não foi possível identificar o perfil atual")
        |> redirect(to: ~p"/connect-platforms")

      is_nil(api_key) or api_key == "" ->
        Logger.error("[steam] STEAM_API_KEY env var is not configured")

        conn
        |> put_flash(:error, "Steam API key não configurada no servidor")
        |> redirect(to: ~p"/connect-platforms")

      true ->
        verify_and_connect(conn, params, profile_id, api_key)
    end
  end

  def callback(conn, _params) do
    conn
    |> put_flash(:error, "Resposta inválida da Steam")
    |> redirect(to: ~p"/connect-platforms")
  end

  defp verify_and_connect(conn, params, profile_id, api_key) do
    with {:ok, steam_id} <- extract_steam_id(params["openid.claimed_id"]),
         :ok <- verify_assertion(params),
         {:ok, _account} <-
           Accounts.connect_platform_account(profile_id, "steam", %{
             "external_user_id" => steam_id,
             "profile_url" => "https://steamcommunity.com/profiles/#{steam_id}",
             "api_key" => api_key
           }) do
      conn
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

  defp verify_assertion(params) do
    form_params =
      params
      |> Enum.filter(fn {key, _} -> is_binary(key) and String.starts_with?(key, "openid.") end)
      |> Map.new()
      |> Map.put("openid.mode", "check_authentication")
      |> Enum.to_list()

    case Req.post(@openid_endpoint, form: form_params) do
      {:ok, %{status: 200, body: body}} ->
        if String.contains?(to_string(body), "is_valid:true"),
          do: :ok,
          else: {:error, :assertion_invalid}

      {:ok, %{status: status}} ->
        {:error, {:verify_http_status, status}}

      {:error, _reason} ->
        {:error, :verify_request_failed}
    end
  end

  defp finish_error(conn, message) do
    conn
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
