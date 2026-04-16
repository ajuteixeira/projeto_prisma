defmodule ProjetoPrisma.Accounts.UserNotifier do
  import Swoosh.Email

  alias ProjetoPrisma.Mailer
  alias ProjetoPrisma.Accounts.User

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"ProjetoPrisma", "contact@example.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Instrucoes para alterar e-mail", """

    ==============================

    Ola #{user.email},

    Voce pode alterar seu e-mail acessando o link abaixo:

    #{url}

    Se voce nao solicitou essa alteracao, ignore este e-mail.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  def deliver_reset_password_instructions(user, url) do
    deliver(user.email, "Instrucoes para redefinir senha", """

    ==============================

    Ola #{user.email},

    Voce pode redefinir sua senha acessando o link abaixo:

    #{url}

    Se voce nao solicitou esta alteracao, ignore este e-mail.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(user, url) do
    case user do
      %User{confirmed_at: nil} -> deliver_confirmation_instructions(user, url)
      _ -> deliver_magic_link_instructions(user, url)
    end
  end

  defp deliver_magic_link_instructions(user, url) do
    deliver(user.email, "Instrucoes de login", """

    ==============================

    Ola #{user.email},

    Voce pode entrar na sua conta acessando o link abaixo:

    #{url}

    Se voce nao solicitou este e-mail, ignore esta mensagem.

    ==============================
    """)
  end

  defp deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Instrucoes de confirmacao", """

    ==============================

    Ola #{user.email},

    Voce pode confirmar sua conta acessando o link abaixo:

    #{url}

    Se voce nao criou uma conta conosco, ignore esta mensagem.

    ==============================
    """)
  end
end
