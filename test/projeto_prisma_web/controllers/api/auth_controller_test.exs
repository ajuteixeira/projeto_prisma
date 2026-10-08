defmodule ProjetoPrismaWeb.Api.AuthControllerTest do
  use ProjetoPrismaWeb.ConnCase, async: true

  import ProjetoPrisma.AccountsFixtures

  alias ProjetoPrisma.Accounts
  alias ProjetoPrisma.Repo
  alias ProjetoPrismaWeb.RegistrationVerification

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

  # Dados de cadastro com um código válido já emitido para o e-mail.
  defp verified_params(attrs \\ %{}, opts \\ []) do
    {code, opts} = Keyword.pop(opts, :code, "123456")
    params = register_params(attrs)
    token = RegistrationVerification.encrypt(params["email"], code, opts)

    Map.merge(params, %{"code" => code, "verification_token" => token})
  end

  # O adaptador de teste do Swoosh entrega o e-mail enviado ao próprio processo.
  defp sent_code do
    assert_received {:email, %{html_body: body}}
    [code] = Regex.run(~r/>(\d{6})</, body, capture: :all_but_first)
    code
  end

  describe "POST /api/auth/register/code" do
    test "envia o código por e-mail e devolve o token", %{conn: conn} do
      params = register_params()

      conn = post(conn, ~p"/api/auth/register/code", params)

      assert %{"verification_token" => token, "expires_in" => 600, "resend_in" => 60} =
               json_response(conn, 202)

      code = sent_code()
      assert RegistrationVerification.check(token, params["email"], code) == :ok
    end

    test "retorna 422 sem enviar e-mail quando o e-mail já está em uso", %{conn: conn} do
      user = user_fixture()

      conn = post(conn, ~p"/api/auth/register/code", register_params(%{"email" => user.email}))

      assert %{"errors" => %{"email" => _}} = json_response(conn, 422)
      # O `user_fixture` já envia a própria confirmação; aqui só importa o código.
      refute_received {:email, %{subject: "Código de confirmação - Prisma"}}
    end

    test "retorna 422 para senha curta", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/register/code", register_params(%{"password" => "123"}))
      assert %{"errors" => %{"password" => _}} = json_response(conn, 422)
    end

    test "limita os envios por e-mail", %{conn: conn} do
      params = register_params()

      for _ <- 1..5 do
        assert build_conn() |> post(~p"/api/auth/register/code", params) |> json_response(202)
      end

      conn = post(conn, ~p"/api/auth/register/code", params)
      assert %{"error" => _} = json_response(conn, 429)
    end
  end

  describe "POST /api/auth/register" do
    test "cria usuário confirmado, perfil e retorna token", %{conn: conn} do
      params = verified_params()

      conn = post(conn, ~p"/api/auth/register", params)

      assert %{"token" => token, "user" => user_json} = json_response(conn, 201)
      assert user_json["email"] == params["email"]
      assert user_json["username"] == params["username"]
      assert Accounts.get_user_by_email(params["email"]).confirmed_at

      # token é válido para autenticação
      conn = build_conn() |> api_conn(token) |> get(~p"/api/auth/me")

      assert %{"user" => %{"email" => email}, "profile" => %{"username" => username}} =
               json_response(conn, 200)

      assert email == params["email"]
      assert username == params["username"]
    end

    test "cria a conta com o código recebido por e-mail", %{conn: conn} do
      params = register_params()

      %{"verification_token" => token} =
        conn |> post(~p"/api/auth/register/code", params) |> json_response(202)

      conn =
        post(
          build_conn(),
          ~p"/api/auth/register",
          Map.merge(params, %{"code" => sent_code(), "verification_token" => token})
        )

      assert %{"token" => _} = json_response(conn, 201)
    end

    test "retorna 422 com código incorreto sem criar a conta", %{conn: conn} do
      params = verified_params(%{}, code: "123456") |> Map.put("code", "654321")

      conn = post(conn, ~p"/api/auth/register", params)

      assert %{"error" => _} = json_response(conn, 422)
      refute Accounts.get_user_by_email(params["email"])
    end

    test "retorna 410 com código expirado", %{conn: conn} do
      params = verified_params(%{}, signed_at: System.system_time(:second) - 601)

      conn = post(conn, ~p"/api/auth/register", params)
      assert %{"error" => _} = json_response(conn, 410)
    end

    test "retorna 400 com token emitido para outro e-mail", %{conn: conn} do
      params = verified_params() |> Map.put("email", unique_user_email())

      conn = post(conn, ~p"/api/auth/register", params)
      assert %{"error" => _} = json_response(conn, 400)
    end

    test "retorna 400 sem código de verificação", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/register", register_params())
      assert %{"error" => _} = json_response(conn, 400)
    end

    test "bloqueia o código depois de 5 tentativas", %{conn: conn} do
      params = verified_params(%{}, code: "123456")

      for _ <- 1..5 do
        wrong = Map.put(params, "code", "000000")
        assert build_conn() |> post(~p"/api/auth/register", wrong) |> json_response(422)
      end

      conn = post(conn, ~p"/api/auth/register", params)
      assert %{"error" => _} = json_response(conn, 429)
    end

    test "retorna 422 para e-mail duplicado", %{conn: conn} do
      params = verified_params()
      post(conn, ~p"/api/auth/register", params)

      conn = post(build_conn(), ~p"/api/auth/register", params)
      assert %{"errors" => %{"email" => _}} = json_response(conn, 422)
    end
  end

  describe "POST /api/auth/availability" do
    test "indica username e e-mail em uso", %{conn: conn} do
      user = user_fixture()

      conn =
        post(conn, ~p"/api/auth/availability", %{
          "username" => String.upcase(user.username),
          "email" => user.email
        })

      assert json_response(conn, 200) == %{"username" => false, "email" => false}
    end

    test "responde só os campos enviados", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/availability", %{"username" => "ninguem_usa_esse"})
      assert json_response(conn, 200) == %{"username" => true}
    end

    test "retorna 400 sem campos", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/availability", %{})
      assert %{"error" => _} = json_response(conn, 400)
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

  describe "DELETE /api/auth/account" do
    test "deleta a conta e retorna 204", %{conn: conn} do
      user = user_fixture()
      {:ok, _profile} = Accounts.create_profile_for_user(user)
      token = Accounts.generate_api_token(user)
      user_id = user.id

      conn = conn |> api_conn(token) |> delete(~p"/api/auth/account")
      assert response(conn, 204)

      # Usuário foi deletado
      assert Repo.get(Accounts.User, user_id) == nil
    end

    test "retorna 401 sem token", %{conn: conn} do
      conn = delete(conn, ~p"/api/auth/account")
      assert %{"error" => _} = json_response(conn, 401)
    end

    test "retorna 401 com token inválido", %{conn: conn} do
      conn = conn |> api_conn("token-invalido") |> delete(~p"/api/auth/account")
      assert %{"error" => _} = json_response(conn, 401)
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
