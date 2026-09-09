defmodule ProjetoPrismaWeb.Api.PlatformControllerTest do
  use ProjetoPrismaWeb.ConnCase, async: true

  import ProjetoPrisma.AccountsFixtures

  alias ProjetoPrisma.Accounts
  alias ProjetoPrisma.Catalog.Platform
  alias ProjetoPrisma.Repo

  defp api_conn(conn, token) do
    put_req_header(conn, "authorization", "Bearer #{token}")
  end

  defp user_with_profile do
    user = user_fixture()
    {:ok, profile} = Accounts.create_profile_for_user(user)
    {user, profile}
  end

  defp platform_fixture(attrs \\ %{}) do
    {:ok, platform} =
      %Platform{}
      |> Platform.changeset(Map.merge(%{name: "Steam", slug: "steam"}, attrs))
      |> Repo.insert()

    platform
  end

  describe "GET /api/platforms" do
    test "retorna 401 sem token", %{conn: conn} do
      conn = get(conn, ~p"/api/platforms")
      assert %{"error" => _} = json_response(conn, 401)
    end

    test "lista plataformas vinculadas", %{conn: conn} do
      {user, profile} = user_with_profile()
      _steam = platform_fixture()

      {:ok, _account} =
        Accounts.connect_platform_account(profile.id, "steam", %{
          "external_user_id" => "76561198000000000",
          "profile_url" => "https://steamcommunity.com/profiles/76561198000000000",
          "api_key" => "steam-key"
        })

      token = Accounts.generate_api_token(user)
      conn = conn |> api_conn(token) |> get(~p"/api/platforms")

      assert %{"platforms" => [platform]} = json_response(conn, 200)
      assert platform["platform"] == "steam"
      assert platform["external_user_id"] == "76561198000000000"
      assert platform["sync_status"] == "idle"
    end

    test "retorna lista vazia sem vínculos", %{conn: conn} do
      {user, _profile} = user_with_profile()
      token = Accounts.generate_api_token(user)

      conn = conn |> api_conn(token) |> get(~p"/api/platforms")
      assert %{"platforms" => []} = json_response(conn, 200)
    end
  end

  describe "POST /api/platforms/:slug/connect-url" do
    test "steam: retorna URL OpenID com state assinado", %{conn: conn} do
      {user, _profile} = user_with_profile()
      token = Accounts.generate_api_token(user)

      conn =
        conn
        |> api_conn(token)
        |> post(~p"/api/platforms/steam/connect-url", %{"api_key" => "minha-steam-key"})

      assert %{"url" => url} = json_response(conn, 200)
      assert url =~ "steamcommunity.com/openid/login"

      query = url |> URI.parse() |> Map.get(:query) |> URI.decode_query()
      assert query["openid.mode"] == "checkid_setup"
      assert query["openid.return_to"] =~ "state="
    end

    test "steam: retorna 422 sem api_key", %{conn: conn} do
      {user, _profile} = user_with_profile()
      token = Accounts.generate_api_token(user)

      conn = conn |> api_conn(token) |> post(~p"/api/platforms/steam/connect-url", %{})
      assert %{"error" => _} = json_response(conn, 422)
    end

    test "retorna 404 para plataforma não suportada", %{conn: conn} do
      {user, _profile} = user_with_profile()
      token = Accounts.generate_api_token(user)

      conn = conn |> api_conn(token) |> post(~p"/api/platforms/psn/connect-url", %{})
      assert %{"error" => _} = json_response(conn, 404)
    end
  end

  describe "DELETE /api/platforms/:slug" do
    test "desvincula conta conectada", %{conn: conn} do
      {user, profile} = user_with_profile()
      _steam = platform_fixture()

      {:ok, _account} =
        Accounts.connect_platform_account(profile.id, "steam", %{
          "external_user_id" => "76561198000000000",
          "profile_url" => "https://steamcommunity.com/profiles/76561198000000000",
          "api_key" => "steam-key"
        })

      token = Accounts.generate_api_token(user)
      conn = conn |> api_conn(token) |> delete(~p"/api/platforms/steam")

      assert response(conn, 204)
      assert Accounts.list_connected_platform_accounts(profile.id) == []
    end

    test "retorna 204 mesmo sem vínculo existente", %{conn: conn} do
      {user, _profile} = user_with_profile()
      _steam = platform_fixture()
      token = Accounts.generate_api_token(user)

      conn = conn |> api_conn(token) |> delete(~p"/api/platforms/steam")
      assert response(conn, 204)
    end

    test "retorna 404 para plataforma inexistente", %{conn: conn} do
      {user, _profile} = user_with_profile()
      token = Accounts.generate_api_token(user)

      conn = conn |> api_conn(token) |> delete(~p"/api/platforms/inexistente")
      assert %{"error" => _} = json_response(conn, 404)
    end
  end
end
