defmodule ProjetoPrismaWeb.Api.AuthController do
  use ProjetoPrismaWeb, :controller

  alias ProjetoPrisma.{Accounts, RateLimiter, Repo}
  alias ProjetoPrismaWeb.ApiJSON
  alias ProjetoPrismaWeb.Plugs.ApiAuth

  @login_rate_limit {10, 300}
  @forgot_password_rate_limit {5, 300}

  @doc """
  POST /api/auth/register

  Body: %{"email" => ..., "password" => ..., "username" => ..., "full_name" => optional}
  """
  def register(conn, params) do
    attrs = Map.take(params, ["email", "password", "username", "full_name"])

    Repo.transact(fn ->
      with {:ok, user} <- Accounts.register_user_with_password(attrs),
           {:ok, _profile} <- Accounts.create_profile_for_user(user) do
        {:ok, {user, Accounts.generate_api_token(user)}}
      end
    end)
    |> case do
      {:ok, {user, token}} ->
        conn
        |> put_status(:created)
        |> json(%{token: token, user: ApiJSON.user(user)})

      {:error, %Ecto.Changeset{} = changeset} ->
        unprocessable(conn, changeset)
    end
  end

  @doc """
  POST /api/auth/login

  Body: %{"email" => ..., "password" => ...}
  """
  def login(conn, %{"email" => email, "password" => password}) do
    {limit, window} = @login_rate_limit

    key =
      {:api_login, client_ip(conn), email |> to_string() |> String.trim() |> String.downcase()}

    case RateLimiter.check(key, limit, window) do
      :ok ->
        if user = Accounts.get_user_by_email_and_password(email, password) do
          token = Accounts.generate_api_token(user)
          json(conn, %{token: token, user: ApiJSON.user(user)})
        else
          # Não revelar se o e-mail existe (user enumeration)
          conn
          |> put_status(:unauthorized)
          |> json(%{error: "Email ou senha invalidos"})
        end

      {:error, :rate_limited} ->
        rate_limited(conn)
    end
  end

  def login(conn, _params) do
    bad_request(conn, "Informe email e senha")
  end

  @doc """
  POST /api/auth/logout — revoga o token usado na requisição.
  """
  def logout(conn, _params) do
    with {:ok, token} <- ApiAuth.bearer_token(conn) do
      Accounts.delete_api_token(token)
    end

    send_resp(conn, :no_content, "")
  end

  @doc """
  GET /api/auth/me — dados do usuário autenticado, perfil e plataformas.
  """
  def me(conn, _params) do
    scope = conn.assigns.current_scope
    profile = Accounts.get_profile_with_user(scope)

    platforms =
      case profile do
        nil ->
          []

        profile ->
          profile.id
          |> Accounts.list_connected_platform_accounts()
          |> Enum.map(&ApiJSON.platform_account/1)
      end

    json(conn, %{
      user: ApiJSON.user(scope.user),
      profile: ApiJSON.profile(profile),
      platforms: platforms
    })
  end

  @doc """
  POST /api/auth/password/forgot — envia e-mail de redefinição de senha.

  Resposta é sempre a mesma, exista ou não a conta (anti user enumeration).
  """
  def forgot_password(conn, %{"email" => email}) do
    {limit, window} = @forgot_password_rate_limit
    key = {:api_forgot_password, email |> to_string() |> String.trim() |> String.downcase()}

    case RateLimiter.check(key, limit, window) do
      :ok ->
        if user = Accounts.get_user_by_email(email) do
          Accounts.deliver_user_reset_password_instructions(
            user,
            &url(~p"/reset-password/#{&1}")
          )
        end

        conn
        |> put_status(:accepted)
        |> json(%{
          message: "Se o e-mail estiver cadastrado, voce recebera as instrucoes em instantes."
        })

      {:error, :rate_limited} ->
        rate_limited(conn)
    end
  end

  def forgot_password(conn, _params) do
    bad_request(conn, "Informe um e-mail valido")
  end

  @doc """
  POST /api/auth/password/reset — redefine a senha usando o token enviado por e-mail.

  Body: %{"token" => ..., "password" => ..., "password_confirmation" => ...}
  """
  def reset_password(conn, %{"token" => token} = params) do
    case Accounts.get_user_by_reset_password_token(token) do
      nil ->
        bad_request(conn, "Token invalido ou expirado")

      user ->
        attrs = Map.take(params, ["password", "password_confirmation"])

        case Accounts.reset_user_password(user, attrs) do
          {:ok, {_user, _expired_tokens}} ->
            json(conn, %{message: "Senha alterada com sucesso"})

          {:error, %Ecto.Changeset{} = changeset} ->
            unprocessable(conn, changeset)
        end
    end
  end

  def reset_password(conn, _params) do
    bad_request(conn, "Informe o token e a nova senha")
  end

  defp unprocessable(conn, changeset) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: ApiJSON.changeset_errors(changeset)})
  end

  defp bad_request(conn, message) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: message})
  end

  defp rate_limited(conn) do
    conn
    |> put_status(:too_many_requests)
    |> json(%{error: "Muitas tentativas. Tente novamente em alguns minutos."})
  end

  defp client_ip(conn) do
    conn.remote_ip |> :inet.ntoa() |> to_string()
  end
end
