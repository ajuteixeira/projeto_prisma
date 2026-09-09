defmodule ProjetoPrismaWeb.Api.PlatformController do
  use ProjetoPrismaWeb, :controller

  alias ProjetoPrisma.Accounts
  alias ProjetoPrisma.Sync.Steam.OpenID
  alias ProjetoPrisma.Sync.Xbox.Auth, as: XboxAuth
  alias ProjetoPrismaWeb.{ApiJSON, PlatformConnect}

  @doc """
  GET /api/platforms — contas de plataforma vinculadas ao perfil do usuário.
  """
  def index(conn, _params) do
    with {:ok, profile} <- current_profile(conn) do
      platforms =
        profile.id
        |> Accounts.list_connected_platform_accounts()
        |> Enum.map(&ApiJSON.platform_account/1)

      json(conn, %{platforms: platforms})
    else
      {:error, conn} -> conn
    end
  end

  @doc """
  POST /api/platforms/:slug/connect-url — gera a URL de autorização da plataforma.

  Steam: body %{"api_key" => "..."} (Steam Web API Key do usuário).
  Xbox: sem body. O app abre a URL retornada no navegador e o callback
  redireciona para o deep link configurado em `:mobile_deep_link`.
  """
  def connect_url(conn, %{"slug" => "steam", "api_key" => api_key})
      when is_binary(api_key) and byte_size(api_key) > 0 do
    with {:ok, profile} <- current_profile(conn) do
      state =
        PlatformConnect.sign(%{
          profile_id: profile.id,
          platform: "steam",
          api_key: String.trim(api_key)
        })

      return_to = url(~p"/auth/steam/callback") <> "?state=" <> URI.encode_www_form(state)

      json(conn, %{url: OpenID.authorize_url(return_to, ProjetoPrismaWeb.Endpoint.url())})
    else
      {:error, conn} -> conn
    end
  end

  def connect_url(conn, %{"slug" => "steam"}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "Informe sua Steam Web API Key para continuar"})
  end

  def connect_url(conn, %{"slug" => "xbox"}) do
    with {:ok, profile} <- current_profile(conn) do
      state = PlatformConnect.sign(%{profile_id: profile.id, platform: "xbox"})
      json(conn, %{url: XboxAuth.authorize_url(state)})
    else
      {:error, conn} -> conn
    end
  end

  def connect_url(conn, %{"slug" => slug}) do
    conn
    |> put_status(:not_found)
    |> json(%{error: "Plataforma #{slug} nao suportada"})
  end

  @doc """
  DELETE /api/platforms/:slug — desvincula a conta da plataforma.
  """
  def delete(conn, %{"slug" => slug}) do
    with {:ok, profile} <- current_profile(conn) do
      case Accounts.disconnect_platform_account(profile.id, slug) do
        {:ok, _} ->
          send_resp(conn, :no_content, "")

        {:error, :sync_in_progress} ->
          conn
          |> put_status(:conflict)
          |> json(%{error: "Sincronizacao em andamento. Tente novamente em alguns minutos."})

        {:error, :platform_not_found} ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "Plataforma #{slug} nao suportada"})
      end
    else
      {:error, conn} -> conn
    end
  end

  defp current_profile(conn) do
    case Accounts.get_profile_with_user(conn.assigns.current_scope) do
      nil ->
        {:error,
         conn
         |> put_status(:not_found)
         |> json(%{error: "Perfil nao encontrado"})
         |> halt()}

      profile ->
        {:ok, profile}
    end
  end
end
