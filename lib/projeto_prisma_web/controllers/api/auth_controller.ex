defmodule ProjetoPrismaWeb.Api.AuthController do
  use ProjetoPrismaWeb, :controller

  alias ProjetoPrisma.{Accounts, RateLimiter, Repo}
  alias ProjetoPrisma.Services.EmailResend
  alias ProjetoPrismaWeb.{ApiJSON, RegistrationVerification}
  alias ProjetoPrismaWeb.Plugs.ApiAuth

  @login_rate_limit {10, 300}
  @forgot_password_rate_limit {5, 300}
  @availability_rate_limit {30, 300}
  @register_code_rate_limit {5, 600}
  # Tentativas por código, como no cadastro web.
  @register_attempt_rate_limit {5, 600}

  @registration_fields ["email", "password", "username", "full_name"]

  @doc """
  POST /api/auth/register/code

  Body: o mesmo de `register`, sem `code` e `verification_token`. Valida os dados,
  inclusive e-mail e username em uso, e só então envia o código por e-mail.

  Responde `202 {verification_token, expires_in, resend_in}`, prazos em segundos;
  `422` erros de campo; `429` mais de 5 envios para o e-mail em 10 min; `503`
  falha no envio.
  """
  def register_code(conn, params) do
    attrs = Map.take(params, @registration_fields)
    {limit, window} = @register_code_rate_limit

    with {:ok, user} <- Accounts.validate_user_registration(attrs),
         :ok <- RateLimiter.check({:api_register_code, user.email}, limit, window),
         code = RegistrationVerification.generate_code(),
         {:ok, _metadata} <- EmailResend.send_verification_code_email(user.email, code) do
      conn
      |> put_status(:accepted)
      |> json(%{
        verification_token: RegistrationVerification.encrypt(user.email, code),
        expires_in: RegistrationVerification.max_age(),
        resend_in: RegistrationVerification.resend_after()
      })
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        unprocessable(conn, changeset)

      {:error, :rate_limited} ->
        rate_limited(conn)

      {:error, _delivery_error} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{error: "Não foi possível enviar o código. Tente novamente."})
    end
  end

  @doc """
  POST /api/auth/register

  Body: %{"email" => ..., "password" => ..., "username" => ..., "full_name" => optional,
  "code" => código recebido por e-mail, "verification_token" => token de `register/code`}.
  Cria a conta só se o código conferir. Responde `201 {token, user}`; `400` sem
  código ou token inválido; `410` código expirado; `422` código incorreto ou erros
  de campo; `429` 5 tentativas no mesmo código.
  """
  def register(conn, %{"code" => code, "verification_token" => token} = params)
      when is_binary(code) and is_binary(token) do
    attrs = Map.take(params, @registration_fields)
    email = attrs |> Map.get("email", "") |> to_string() |> String.trim() |> String.downcase()
    {limit, window} = @register_attempt_rate_limit

    with :ok <- RateLimiter.check({:api_register_attempt, token_key(token)}, limit, window),
         :ok <- RegistrationVerification.check(token, email, String.trim(code)) do
      create_account(conn, attrs)
    else
      {:error, :rate_limited} ->
        conn
        |> put_status(:too_many_requests)
        |> json(%{error: "Muitas tentativas incorretas. Solicite um novo código."})

      {:error, :invalid_code} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Código incorreto. Confira e tente de novo."})

      {:error, :expired} ->
        conn
        |> put_status(:gone)
        |> json(%{error: "O código expirou. Solicite um novo."})

      {:error, :invalid_token} ->
        bad_request(conn, "Código de verificação inválido. Solicite um novo.")
    end
  end

  def register(conn, _params) do
    bad_request(conn, "Informe o código de verificação enviado por e-mail")
  end

  defp create_account(conn, attrs) do
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
  POST /api/auth/availability — confere se username e/ou e-mail estão livres.

  Body: %{"username" => optional, "email" => optional}. Responde só as chaves
  enviadas, ex.: `%{"username" => true, "email" => false}` (`true` = disponível).
  Como o cadastro já revela e-mails em uso (`422`), limitamos por IP para
  dificultar enumeração em massa.
  """
  def availability(conn, params) do
    checks =
      [
        {"username", &Accounts.username_available?/1},
        {"email", &Accounts.email_available?/1}
      ]
      |> Enum.flat_map(fn {field, available?} ->
        case params[field] do
          value when is_binary(value) and value != "" -> [{field, available?.(value)}]
          _ -> []
        end
      end)

    {limit, window} = @availability_rate_limit

    cond do
      checks == [] ->
        bad_request(conn, "Informe username ou email")

      RateLimiter.check({:api_availability, client_ip(conn)}, limit, window) != :ok ->
        rate_limited(conn)

      true ->
        json(conn, Map.new(checks))
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

  # O token tem centenas de bytes; a chave do limitador só precisa identificá-lo.
  defp token_key(token), do: :crypto.hash(:sha256, token)
end
