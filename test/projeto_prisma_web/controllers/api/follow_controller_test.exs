defmodule ProjetoPrismaWeb.Api.FollowControllerTest do
  use ProjetoPrismaWeb.ConnCase, async: true

  import ProjetoPrisma.AccountsFixtures

  alias ProjetoPrisma.Accounts
  alias ProjetoPrisma.Repo

  defp api_conn(conn, token), do: put_req_header(conn, "authorization", "Bearer #{token}")

  defp profile_fixture(attrs \\ %{}) do
    user = user_fixture(attrs)

    if name = attrs[:full_name] do
      user |> Ecto.Changeset.change(full_name: name) |> Repo.update!()
    end

    {:ok, profile} = Accounts.create_profile_for_user(user)
    {user, profile}
  end

  setup %{conn: conn} do
    {user, profile} = profile_fixture()
    %{conn: api_conn(conn, Accounts.generate_api_token(user)), me: profile}
  end

  test "retorna 401 sem token" do
    assert %{"error" => _} = build_conn() |> get(~p"/api/follows") |> json_response(401)
  end

  test "retorna 404 quando o usuário não tem perfil" do
    token = Accounts.generate_api_token(user_fixture())

    assert %{"error" => _} =
             build_conn() |> api_conn(token) |> get(~p"/api/follows") |> json_response(404)
  end

  describe "GET /api/follows" do
    test "lista seguidores e seguidos com o estado de follow", %{conn: conn, me: me} do
      {_, fan} = profile_fixture(%{full_name: "Ana Souza"})
      {_, idol} = profile_fixture()
      :ok = Accounts.follow_profile(fan.id, me.id)
      :ok = Accounts.follow_profile(me.id, idol.id)

      body = conn |> get(~p"/api/follows") |> json_response(200)

      assert body["followers"] == [
               %{
                 "profile_id" => fan.id,
                 "username" => fan.username,
                 "display_name" => "Ana Souza",
                 "avatar_url" => nil,
                 "is_following" => false
               }
             ]

      assert [%{"profile_id" => id, "display_name" => name, "is_following" => true}] =
               body["following"]

      assert id == idol.id
      assert name == idol.username
    end
  end

  describe "GET /api/follows/search" do
    test "busca por username sem incluir o próprio usuário", %{conn: conn, me: me} do
      {_, other} = profile_fixture()

      %{"results" => results} =
        conn |> get(~p"/api/follows/search?q=user_") |> json_response(200)

      ids = Enum.map(results, & &1["profile_id"])
      assert other.id in ids
      refute me.id in ids
    end

    test "busca vazia não retorna ninguém", %{conn: conn} do
      profile_fixture()
      assert %{"results" => []} = conn |> get(~p"/api/follows/search?q=") |> json_response(200)
    end
  end

  describe "PUT/DELETE /api/follows/:profile_id" do
    test "segue e deixa de seguir", %{conn: conn, me: me} do
      {_, other} = profile_fixture()

      assert conn |> put(~p"/api/follows/#{other.id}") |> response(204)
      assert Accounts.following?(me.id, other.id)
      # idempotente
      assert conn |> put(~p"/api/follows/#{other.id}") |> response(204)

      assert conn |> delete(~p"/api/follows/#{other.id}") |> response(204)
      refute Accounts.following?(me.id, other.id)
    end

    test "não deixa seguir a si mesmo", %{conn: conn, me: me} do
      assert %{"error" => _} = conn |> put(~p"/api/follows/#{me.id}") |> json_response(422)
    end

    test "retorna 404 para perfil inexistente e 400 para id inválido", %{conn: conn} do
      assert %{"error" => _} = conn |> put(~p"/api/follows/999999999") |> json_response(404)
      assert %{"error" => _} = conn |> delete(~p"/api/follows/abc") |> json_response(400)
    end
  end
end
