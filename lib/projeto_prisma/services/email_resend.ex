defmodule ProjetoPrisma.Services.EmailResend do

  @from_email "onboarding@resend.dev"

  def send_password_reset_email(email, reset_url) do
    client = Resend.client(api_key: get_api_key())

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

    send_email(
      to: email,
      subject: "Recuperação de Senha - Prisma",
      html: html_body
    )
  end

  def send_email(opts) do
    client = Resend.client(api_key: get_api_key())

    email_params = %{
      from: Keyword.get(opts, :from, @from_email),
      to: Keyword.get(opts, :to),
      subject: Keyword.get(opts, :subject),
      html: Keyword.get(opts, :html)
    }

    case Resend.Emails.send(client, email_params) do
      {:ok, response} ->
        {:ok, response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_api_key do
    System.get_env("RESEND_API_KEY") ||
      raise "RESEND_API_KEY environment variable is not set"
  end
end
