defmodule ProjetoPrismaWeb.PageController do
  use ProjetoPrismaWeb, :controller

  alias ProjetoPrisma.Accounts
  alias ProjetoPrismaWeb.UserAuth
  alias ProjetoPrisma.RateLimiter
  alias ProjetoPrisma.Services.EmailResend

  def home(conn, _params) do
    render(conn, :home)
  end

  def connect_platforms(conn, _params) do
    render(conn, :connect_platforms)
  end

  def register(conn, _params) do
    redirect(conn, to: ~p"/users/register")
  end

  def complete_registration(conn, %{"token" => token}) do
    case Phoenix.Token.verify(ProjetoPrismaWeb.Endpoint, "registration", token, max_age: 300) do
      {:ok, %{user_id: user_id, profile_id: profile_id}} ->
        user = Accounts.get_user!(user_id)

        conn
        |> put_session(:user_return_to, "/connect-platforms")
        |> UserAuth.log_in_user(user)
        |> put_session(:profile_id, profile_id)
        |> put_flash(:info, "Conta criada com sucesso!")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Link de registro expirado ou invalido")
        |> redirect(to: ~p"/register")
    end
  end

  def complete_registration(conn, _params) do
    conn
    |> put_flash(:error, "Token de registro invalido")
    |> redirect(to: ~p"/register")
  end

  def forgot_password(conn, _params) do
    render(conn, :forgot_password)
  end

  def submit_forgot_password(conn, %{"email" => email}) do
    normalized_email = email |> String.trim() |> String.downcase()
    ip = Tuple.to_list(conn.remote_ip) |> Enum.join(".")

    with :ok <- RateLimiter.check({:forgot_password_ip, ip}, 10, 3600),
         :ok <- RateLimiter.check({:forgot_password_email, normalized_email}, 3, 3600) do
      case Accounts.get_user_by_email(normalized_email) do
        nil ->
          conn
          |> put_flash(:error, "Este e-mail não está registrado em nossa base de dados")
          |> redirect(to: ~p"/forgot-password")

        user ->
          # Gera token assinado com validade de 1 hora
          reset_token =
            Phoenix.Token.sign(ProjetoPrismaWeb.Endpoint, "reset_password", %{
              email: user.email,
              password_hash: user.hashed_password
            })

          # Constrói a URL de reset
          reset_url = ProjetoPrismaWeb.Endpoint.url() <> "/reset-password?token=#{reset_token}&email=#{URI.encode(user.email)}"

          # Envia o email
          case EmailResend.send_password_reset_email(user.email, reset_url) do
            {:ok, _response} ->
              conn
              |> put_flash(:info, "E-mail de recuperação enviado com sucesso!")
              |> redirect(to: ~p"/forgot-password")

            {:error, _reason} ->
              conn
              |> put_flash(:error, "Erro ao enviar e-mail de recuperação. Tente novamente.")
              |> redirect(to: ~p"/forgot-password")
          end
      end
    else
      {:error, :rate_limited} ->
        conn
        |> put_flash(:error, "Muitas tentativas. Aguarde alguns minutos antes de tentar novamente.")
        |> redirect(to: ~p"/forgot-password")
    end
  end

  def reset_password(conn, params) do
    token = Map.get(params, "token", "")

    case verify_reset_password_token(token) do
      {:ok, user} ->
        render(conn, :reset_password, email: user.email, token: token)

      {:error, :expired} ->
        conn
        |> put_flash(:error, "O link de recuperação expirou. Solicite um novo.")
        |> redirect(to: ~p"/forgot-password")

      {:error, :used} ->
        conn
        |> put_flash(:error, "Este link de recuperação já foi utilizado. Solicite um novo.")
        |> redirect(to: ~p"/forgot-password")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Link de recuperação inválido.")
        |> redirect(to: ~p"/forgot-password")
    end
  end

  def submit_reset_password(conn, %{"email" => _email, "token" => token, "password" => password, "password_confirmation" => password_confirmation}) do
    case verify_reset_password_token(token) do
      {:error, :expired} ->
        conn
        |> put_flash(:error, "O link de recuperação expirou. Solicite um novo.")
        |> redirect(to: ~p"/forgot-password")

      {:error, :used} ->
        conn
        |> put_flash(:error, "Este link de recuperação já foi utilizado. Solicite um novo.")
        |> redirect(to: ~p"/forgot-password")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Link de recuperação inválido.")
        |> redirect(to: ~p"/forgot-password")

      {:ok, user} ->
        cond do
          String.trim(password) != String.trim(password_confirmation) ->
            conn
            |> put_flash(:error, "As senhas não coincidem.")
            |> redirect(to: "/reset-password?token=#{URI.encode(token)}&email=#{URI.encode(user.email)}")

          true ->
            case Accounts.reset_user_password_by_email(user.email, password) do
              {:ok, _user} ->
                conn
                |> put_flash(:info, "Senha redefinida com sucesso.")
                |> redirect(to: ~p"/login")

              {:error, :not_found} ->
                conn
                |> put_flash(:error, "Usuário não encontrado para este link.")
                |> redirect(to: ~p"/forgot-password")

              {:error, %Ecto.Changeset{} = changeset} ->
                errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
                error_msg = errors |> Map.values() |> List.flatten() |> Enum.join(", ")

                conn
                |> put_flash(:error, "Erro ao redefinir senha: #{error_msg}")
                |> redirect(to: "/reset-password?token=#{URI.encode(token)}&email=#{URI.encode(user.email)}")
            end
        end
    end
  end

  def submit_reset_password(conn, _params) do
    conn
    |> put_flash(:error, "Dados inválidos para redefinição de senha.")
    |> redirect(to: ~p"/forgot-password")
  end

  def submit_forgot_password(conn, _params) do
    conn
    |> put_flash(:error, "E-mail inválido")
    |> redirect(to: ~p"/forgot-password")
  end

  defp verify_reset_password_token(token) do
    case Phoenix.Token.verify(ProjetoPrismaWeb.Endpoint, "reset_password", token, max_age: 3600) do
      {:ok, %{email: token_email, password_hash: token_password_hash}} ->
        case Accounts.get_user_by_email(token_email) do
          nil ->
            {:error, :invalid}

          user when user.hashed_password == token_password_hash ->
            {:ok, user}

          _user ->
            {:error, :used}
        end

      # Compatibilidade com tokens antigos emitidos antes da validação por hash.
      {:ok, token_email} when is_binary(token_email) ->
        case Accounts.get_user_by_email(token_email) do
          nil -> {:error, :invalid}
          user -> {:ok, user}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
