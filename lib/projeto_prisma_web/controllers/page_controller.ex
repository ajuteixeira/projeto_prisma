defmodule ProjetoPrismaWeb.PageController do
  use ProjetoPrismaWeb, :controller

  alias ProjetoPrisma.Accounts

  def home(conn, _params) do
    render(conn, :home)
  end

  def connect_platforms(conn, _params) do
    render(conn, :connect_platforms)
  end

  def register(conn, _params) do
    render(conn, :register)
  end

  def create_profile(conn, %{"nickname" => nickname}) do
    nickname = nickname |> String.trim() |> String.downcase() |> String.replace(~r/\s+/, "_")

    case Accounts.get_or_create_profile(%{username: nickname}) do
      {:ok, profile} ->
        conn
        |> put_session(:profile_id, profile.id)
        |> put_flash(:info, "Conta criada com sucesso!")
        |> redirect(to: ~p"/connect-platforms")

      {:error, changeset} ->
        errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
        error_msg = errors |> Map.values() |> List.flatten() |> Enum.join(", ")

        conn
        |> put_flash(:error, "Erro ao criar conta: #{error_msg}")
        |> redirect(to: ~p"/register")
    end
  end

  def create_profile(conn, _params) do
    conn
    |> put_flash(:error, "Nickname e obrigatorio")
    |> redirect(to: ~p"/register")
  end
end
