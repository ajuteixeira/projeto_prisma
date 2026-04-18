defmodule ProjetoPrismaWeb.PageController do
  use ProjetoPrismaWeb, :controller

  alias ProjetoPrisma.Accounts
  alias ProjetoPrismaWeb.UserAuth

  def home(conn, _params) do
    render(conn, :home)
  end

  def connect_platforms(conn, _params) do
    render(conn, :connect_platforms)
  end

  def dashboard(conn, _params) do
    render(conn, :dashboard)
  end

  def profile(conn, _params) do
    render(conn, :profile)
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

end
