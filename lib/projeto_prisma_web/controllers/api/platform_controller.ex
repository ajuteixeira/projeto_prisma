defmodule ProjetoPrismaWeb.Api.PlatformController do
  use ProjetoPrismaWeb, :controller

  alias ProjetoPrisma.{Accounts, Repo}
  alias ProjetoPrisma.Accounts.PlatformOwnership
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

  # Plataformas vinculadas por credenciais + código no perfil (sem OAuth).
  @ownership_platforms ~w(playstation retroachievements)

  @doc """
  POST /api/platforms/:slug/verification-code — emite o código de posse.

  Só para PSN e RetroAchievements. Responde `{code, verification_token, expires_in}`:
  o usuário cola `code` no "Sobre Mim" (PSN) ou no "Motto" (RetroAchievements) e o
  app devolve `verification_token` em `POST /api/platforms/:slug/connect`.
  """
  def verification_code(conn, %{"slug" => slug}) when slug in @ownership_platforms do
    with {:ok, profile} <- current_profile(conn) do
      code = PlatformOwnership.generate_code()

      token =
        PlatformConnect.sign_verification(%{profile_id: profile.id, platform: slug, code: code})

      json(conn, %{
        code: code,
        verification_token: token,
        expires_in: PlatformConnect.verification_max_age()
      })
    else
      {:error, conn} -> conn
    end
  end

  def verification_code(conn, %{"slug" => slug}), do: unsupported(conn, slug)

  @doc """
  POST /api/platforms/:slug/connect — vincula PSN ou RetroAchievements.

  Body: %{"username" => PSN ID ou usuário RA, "api_key" => NPSSO ou Web API Key,
  "verification_token" => token de `verification-code`}. Responde `{platform}` com a
  conta vinculada, `410` se o código expirou ou `422` com `{error, reason}`.
  """
  def connect(conn, %{"slug" => slug} = params) when slug in @ownership_platforms do
    username = trimmed(params["username"])
    api_key = trimmed(params["api_key"])

    with {:ok, profile} <- current_profile(conn),
         {:ok, code} <- verified_code(conn, params["verification_token"], profile.id, slug) do
      if username == "" or api_key == "" do
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Preencha usuário e chave para continuar", reason: "missing_fields"})
      else
        case PlatformOwnership.connect(profile.id, slug, username, api_key, code) do
          {:ok, account} ->
            json(conn, %{platform: ApiJSON.platform_account(Repo.preload(account, :platform))})

          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{
              error: PlatformOwnership.error_message(slug, reason),
              reason: reason_code(reason)
            })
        end
      end
    else
      {:error, conn} -> conn
    end
  end

  def connect(conn, %{"slug" => slug}), do: unsupported(conn, slug)

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

  defp verified_code(conn, token, profile_id, slug) do
    case PlatformConnect.verify_verification(token) do
      {:ok, %{profile_id: ^profile_id, platform: ^slug, code: code}} ->
        {:ok, code}

      _ ->
        {:error,
         conn
         |> put_status(:gone)
         |> json(%{
           error: "Código de verificação expirado. Gere um novo código e tente novamente.",
           reason: "verification_expired"
         })
         |> halt()}
    end
  end

  defp reason_code({:http_status, _status}), do: "http_status"
  defp reason_code(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp reason_code(_reason), do: "invalid"

  defp trimmed(value) when is_binary(value), do: String.trim(value)
  defp trimmed(_value), do: ""

  defp unsupported(conn, slug) do
    conn
    |> put_status(:not_found)
    |> json(%{error: "Plataforma #{slug} nao suportada"})
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
