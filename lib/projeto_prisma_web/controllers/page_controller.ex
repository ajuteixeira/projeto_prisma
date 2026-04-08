defmodule ProjetoPrismaWeb.PageController do
  use ProjetoPrismaWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def connect_platforms(conn, _params) do
    render(conn, :connect_platforms)
  end

  def register(conn, _params) do
    render(conn, :register)
  end

  def complete_registration(conn, %{"token" => token}) do
    case Phoenix.Token.verify(ProjetoPrismaWeb.Endpoint, "registration", token, max_age: 300) do
      {:ok, %{user_id: user_id, profile_id: profile_id}} ->
        conn
        |> put_session(:user_id, user_id)
        |> put_session(:profile_id, profile_id)
        |> put_flash(:info, "Conta criada com sucesso!")
        |> redirect(to: ~p"/connect-platforms")

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
