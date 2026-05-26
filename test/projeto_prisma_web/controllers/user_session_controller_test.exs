defmodule ProjetoPrismaWeb.UserSessionControllerTest do
  use ProjetoPrismaWeb.ConnCase, async: true

  import ProjetoPrisma.AccountsFixtures
  alias ProjetoPrisma.Accounts

  setup do
    %{unconfirmed_user: unconfirmed_user_fixture(), user: user_fixture()}
  end

  describe "GET /users/log-in" do
    test "renders login page", %{conn: conn} do
      conn = get(conn, ~p"/users/log-in")
      response = html_response(conn, 200)
      assert response =~ "PRISMA"
      assert response =~ ~p"/users/register"
      assert response =~ "Entrar"
    end

    test "renders login page with email filled in (sudo mode)", %{conn: conn, user: user} do
      conn =
        conn
        |> log_in_user(user)
        |> get(~p"/users/log-in")

      assert redirected_to(conn) == ~p"/connect-platforms"
    end

    test "renders login page (email + password)", %{conn: conn} do
      conn = get(conn, ~p"/users/log-in?mode=password")
      response = html_response(conn, 200)
      assert response =~ "PRISMA"
      assert response =~ ~p"/users/register"
      assert response =~ "Entrar"
    end
  end

  describe "GET /users/log-in/:token" do
    test "renders confirmation page for unconfirmed user", %{conn: conn, unconfirmed_user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(user, url)
        end)

      conn = get(conn, ~p"/users/log-in/#{token}")
      assert html_response(conn, 200) =~ "Confirmar e manter conectado"
    end

    test "renders login page for confirmed user", %{conn: conn, user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(user, url)
        end)

      conn = get(conn, ~p"/users/log-in/#{token}")
      html = html_response(conn, 200)
      refute html =~ "Confirmar e manter conectado"
      assert html =~ "Entrar"
    end

    test "raises error for invalid token", %{conn: conn} do
      conn = get(conn, ~p"/users/log-in/invalid-token")
      assert redirected_to(conn) == ~p"/users/log-in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "O magic link e invalido ou expirou."
    end
  end

  describe "POST /users/log-in - email and password" do
    test "logs the user in", %{conn: conn, user: user} do
      user = set_password(user)

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/connect-platforms"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/connect-platforms")
      response = html_response(conn, 200)
      assert response =~ "Vincular Conta"
    end

    test "logs the user in with remember me", %{conn: conn, user: user} do
      user = set_password(user)

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_projeto_prisma_web_user_remember_me"]
      assert redirected_to(conn) == ~p"/connect-platforms"
    end

    test "logs the user in with return to", %{conn: conn, user: user} do
      user = set_password(user)

      conn =
        conn
        |> init_test_session(user_return_to: "/foo/bar")
        |> post(~p"/users/log-in", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password()
          }
        })

      assert redirected_to(conn) == ~p"/connect-platforms"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Bem-vindo de volta!"
    end

    test "emits error message with invalid credentials", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/log-in?mode=password", %{
          "user" => %{"email" => user.email, "password" => "invalid_password"}
        })

      response = html_response(conn, 200)
      assert response =~ "PRISMA"
      assert response =~ "Email ou senha invalidos"
    end
  end

  describe "POST /users/log-in - magic link" do
    test "sends magic link email when user exists", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"email" => user.email}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Se o seu e-mail estiver em nosso sistema, voce recebera instrucoes de acesso em instantes."

      assert ProjetoPrisma.Repo.get_by!(Accounts.UserToken, user_id: user.id).context == "login"
    end

    test "logs the user in", %{conn: conn, user: user} do
      {token, _hashed_token} = generate_user_magic_link_token(user)

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"token" => token}
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/connect-platforms"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/connect-platforms")
      response = html_response(conn, 200)
      assert response =~ "Vincular Conta"
    end

    test "confirms unconfirmed user", %{conn: conn, unconfirmed_user: user} do
      {token, _hashed_token} = generate_user_magic_link_token(user)
      refute user.confirmed_at

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"token" => token},
          "_action" => "confirmed"
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/connect-platforms"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Usuario confirmado com sucesso."

      assert Accounts.get_user!(user.id).confirmed_at

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/connect-platforms")
      response = html_response(conn, 200)
      assert response =~ "Vincular Conta"
    end

    test "emits error message when magic link is invalid", %{conn: conn} do
      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"token" => "invalid"}
        })

      assert html_response(conn, 200) =~ "O link e invalido ou expirou."
    end
  end

  describe "DELETE /users/log-out" do
    test "logs the user out", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> delete(~p"/users/log-out")
      assert redirected_to(conn) == ~p"/users/log-in"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logout realizado com sucesso."
    end

    test "succeeds even if the user is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/users/log-out")
      assert redirected_to(conn) == ~p"/users/log-in"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logout realizado com sucesso."
    end
  end
end
