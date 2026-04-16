defmodule ProjetoPrismaWeb.UserResetPasswordController do
  use ProjetoPrismaWeb, :controller

  alias ProjetoPrisma.Accounts

  def new(conn, _params) do
    form = Phoenix.Component.to_form(%{}, as: "user")
    render(conn, :new, form: form)
  end

  def create(conn, %{"user" => %{"email" => email}}) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_reset_password_instructions(
        user,
        &url(~p"/reset-password/#{&1}")
      )
    end

    info =
      "Se o seu e-mail estiver em nosso sistema, voce recebera instrucoes para redefinir a senha em instantes."

    conn
    |> put_flash(:info, info)
    |> redirect(to: ~p"/reset-password")
  end

  # Backward compatibility with old form payload: %{"email" => "..."}
  def create(conn, %{"email" => email}) do
    create(conn, %{"user" => %{"email" => email}})
  end

  def create(conn, _params) do
    conn
    |> put_flash(:error, "Informe um e-mail valido.")
    |> redirect(to: ~p"/reset-password")
  end

  def edit(conn, %{"token" => token}) do
    if user = Accounts.get_user_by_reset_password_token(token) do
      form =
        user
        |> Accounts.change_user_password()
        |> Phoenix.Component.to_form(as: "user")

      render(conn, :edit, token: token, form: form)
    else
      conn
      |> put_flash(:error, "O link de redefinicao de senha e invalido ou expirou.")
      |> redirect(to: ~p"/reset-password")
    end
  end

  def update(conn, %{"token" => token, "user" => user_params}) do
    case Accounts.get_user_by_reset_password_token(token) do
      nil ->
        conn
        |> put_flash(:error, "O link de redefinicao de senha e invalido ou expirou.")
        |> redirect(to: ~p"/reset-password")

      user ->
        case Accounts.reset_user_password(user, user_params) do
          {:ok, {_user, _expired_tokens}} ->
            conn
            |> put_flash(:info, "Senha alterada com sucesso.")
            |> redirect(to: ~p"/users/log-in")

          {:error, changeset} ->
            form = Phoenix.Component.to_form(changeset, as: "user")
            render(conn, :edit, token: token, form: form)
        end
    end
  end
end
