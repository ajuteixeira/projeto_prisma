defmodule ProjetoPrismaWeb.Api.AuthControllerTest do
  use ProjetoPrismaWeb.ConnCase, async: true

  import ProjetoPrisma.AccountsFixtures

  alias ProjetoPrisma.Accounts
  alias ProjetoPrisma.Repo

  defp api_conn(conn, token) do
    put_req_header(conn, "authorization", "Bearer #{token}")
  end

  defp register_params(attrs \\ %{}) do
    Map.merge(
      %{
        "email" => unique_user_email(),
        "username" => unique_user_username(),
        "password" => valid_user_password()
      },
      attrs
    )
  end

  describe "POST /api/auth/register" do
    test "cria usuário, perfil e retorna token", %{conn: conn} do
      params = register_params()

      conn = post(conn, ~p"/api/auth/register", params)

      assert %{"token" => token, "user" => user_json} = json_response(conn, 201)
      assert user_json["email"] == params["email"]
      assert user_json["username"] == params["username"]

      # token é válido para autenticação
      conn = build_conn() |> api_conn(token) |> get(~p"/api/auth/me")

      assert %{"user" => %{"email" => email}, "profile" => %{"username" => username}} =
               json_response(conn, 200)

      assert email == params["email"]
      assert username == params["username"]
    end

    test "retorna 422 para e-mail duplicado", %{conn: conn} do
      params = register_params()
      post(conn, ~p"/api/auth/register", params)

      conn = post(build_conn(), ~p"/api/auth/register", params)
      assert %{"errors" => %{"email" => _}} = json_response(conn, 422)
    end

    test "retorna 422 para senha curta", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/register", register_params(%{"password" => "123"}))
      assert %{"errors" => %{"password" => _}} = json_response(conn, 422)
    end
  end

  describe "POST /api/auth/login" do
    setup do
      user = user_fixture() |> set_password()
      %{user: user}
    end

    test "retorna token com credenciais válidas", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/api/auth/login", %{
          "email" => user.email,
          "password" => valid_user_password()
        })

      assert %{"token" => token, "user" => %{"email" => email}} = json_response(conn, 200)
      assert email == user.email
      assert Accounts.get_user_by_api_token(token).id == user.id
    end

    test "retorna 401 com senha inválida", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/api/auth/login", %{
          "email" => user.email,
          "password" => "senha-errada"
        })

      assert %{"error" => _} = json_response(conn, 401)
    end

    test "retorna 401 com e-mail inexistente", %{conn: conn} do
      conn =
        post(conn, ~p"/api/auth/login", %{
          "email" => "ninguem@example.com",
          "password" => valid_user_password()
        })

      assert %{"error" => _} = json_response(conn, 401)
    end

    test "retorna 400 sem credenciais", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/login", %{})
      assert %{"error" => _} = json_response(conn, 400)
    end
  end

  describe "GET /api/auth/me" do
    test "retorna 401 sem token", %{conn: conn} do
      conn = get(conn, ~p"/api/auth/me")
      assert %{"error" => _} = json_response(conn, 401)
    end

    test "retorna 401 com token inválido", %{conn: conn} do
      conn = conn |> api_conn("token-invalido") |> get(~p"/api/auth/me")
      assert %{"error" => _} = json_response(conn, 401)
    end

    test "retorna usuário, perfil e plataformas", %{conn: conn} do
      user = user_fixture()
      {:ok, _profile} = Accounts.create_profile_for_user(user)
      token = Accounts.generate_api_token(user)

      conn = conn |> api_conn(token) |> get(~p"/api/auth/me")

      assert %{"user" => %{"email" => email}, "profile" => %{"id" => _}, "platforms" => []} =
               json_response(conn, 200)

      assert email == user.email
    end
  end

  describe "POST /api/auth/logout" do
    test "revoga o token", %{conn: conn} do
      user = user_fixture()
      token = Accounts.generate_api_token(user)

      conn = conn |> api_conn(token) |> post(~p"/api/auth/logout")
      assert response(conn, 204)

      assert Accounts.get_user_by_api_token(token) == nil
    end
  end

  describe "POST /api/auth/password/forgot" do
    test "retorna 202 para e-mail cadastrado", %{conn: conn} do
      user = user_fixture()

      conn = post(conn, ~p"/api/auth/password/forgot", %{"email" => user.email})
      assert %{"message" => _} = json_response(conn, 202)
    end

    test "retorna 202 mesmo para e-mail não cadastrado", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/password/forgot", %{"email" => "ninguem@example.com"})
      assert %{"message" => _} = json_response(conn, 202)
    end
  end

  describe "POST /api/auth/password/reset" do
    setup do
      user = user_fixture()

      {token, user_token} = Accounts.UserToken.build_email_token(user, "reset_password")
      Repo.insert!(user_token)

      %{user: user, token: token}
    end

    test "redefine a senha com token válido", %{conn: conn, user: user, token: token} do
      conn =
        post(conn, ~p"/api/auth/password/reset", %{
          "token" => token,
          "password" => "nova senha 123",
          "password_confirmation" => "nova senha 123"
        })

      assert %{"message" => _} = json_response(conn, 200)
      assert Accounts.get_user_by_email_and_password(user.email, "nova senha 123")
    end

    test "retorna 400 com token inválido", %{conn: conn} do
      conn =
        post(conn, ~p"/api/auth/password/reset", %{
          "token" => "invalido",
          "password" => "nova senha 123",
          "password_confirmation" => "nova senha 123"
        })

      assert %{"error" => _} = json_response(conn, 400)
    end

    test "retorna 422 quando a confirmação não confere", %{conn: conn, token: token} do
      conn =
        post(conn, ~p"/api/auth/password/reset", %{
          "token" => token,
          "password" => "nova senha 123",
          "password_confirmation" => "outra senha"
        })

      assert %{"errors" => _} = json_response(conn, 422)
    end
  end
end
