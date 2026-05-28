defmodule ProjetoPrisma.Services.EmailResend do
  import Swoosh.Email
  alias ProjetoPrisma.Mailer

  def send_password_reset_email(to_email, reset_url) do
    html_body = """
    <div style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
      <h2>Recuperação de Senha</h2>
      <p>Olá,</p>
      <p>Recebemos uma solicitação para redefinir sua senha. Clique no link abaixo para criar uma nova senha:</p>
      <p>
        <a href="#{reset_url}" style="background-color: #007bff; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px; display: inline-block;">
          Redefinir Senha
        </a>
      </p>
      <p style="color: #666; font-size: 12px;">Este link expira em 1 hora.</p>
      <hr />
      <p style="color: #999; font-size: 12px;">Se você não solicitou uma mudança de senha, ignore este email.</p>
    </div>
    """

    from_email = System.get_env("GMAIL_USER")

    new()
    |> from(from_email)
    |> to(to_email)
    |> subject("Recuperação de Senha - Prisma")
    |> html_body(html_body)
    |> Mailer.deliver()
  end

  def send_verification_code_email(to_email, code) do
    html_body = """
    <div style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
      <h2>Confirme seu email</h2>
      <p>Use o código abaixo para confirmar seu cadastro no Prisma:</p>
      <div style="text-align: center; margin: 32px 0;">
        <span style="font-size: 36px; font-weight: bold; letter-spacing: 12px; color: #007bff;">#{code}</span>
      </div>
      <p style="color: #666; font-size: 12px;">Este código expira em 10 minutos.</p>
      <hr />
      <p style="color: #999; font-size: 12px;">Se você não solicitou este cadastro, ignore este email.</p>
    </div>
    """

    from_email = System.get_env("GMAIL_USER")

    new()
    |> from(from_email)
    |> to(to_email)
    |> subject("Código de confirmação - Prisma")
    |> html_body(html_body)
    |> Mailer.deliver()
  end
end
