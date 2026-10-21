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
    test "retorna as contagens das abas", %{conn: conn, me: me} do
      {_, fan} = profile_fixture()
      {_, idol} = profile_fixture()
      {_, other} = profile_fixture()
      :ok = Accounts.follow_profile(fan.id, me.id)
      :ok = Accounts.follow_profile(me.id, idol.id)
      :ok = Accounts.follow_profile(me.id, other.id)

      assert conn |> get(~p"/api/follows") |> json_response(200) ==
               %{"followers_count" => 1, "following_count" => 2}
    end
  end

  describe "GET /api/follows/followers e /following" do
    test "lista com o estado de follow", %{conn: conn, me: me} do
      {_, fan} = profile_fixture(%{full_name: "Ana Souza"})
      {_, idol} = profile_fixture()
      :ok = Accounts.follow_profile(fan.id, me.id)
      :ok = Accounts.follow_profile(me.id, idol.id)

      assert conn |> get(~p"/api/follows/followers") |> json_response(200) == %{
               "results" => [
                 %{
                   "profile_id" => fan.id,
                   "username" => fan.username,
                   "display_name" => "Ana Souza",
                   "avatar_url" => nil,
                   "is_following" => false
                 }
               ],
               "next_offset" => nil
             }

      assert %{
               "results" => [
                 %{"profile_id" => id, "display_name" => name, "is_following" => true}
               ]
             } =
               conn |> get(~p"/api/follows/following") |> json_response(200)

      assert id == idol.id
      assert name == idol.username
    end

    test "pagina com offset e limit", %{conn: conn, me: me} do
      fans = for _ <- 1..3, do: elem(profile_fixture(), 1)
      Enum.each(fans, &(:ok = Accounts.follow_profile(&1.id, me.id)))

      first = conn |> get(~p"/api/follows/followers?limit=2") |> json_response(200)
      assert length(first["results"]) == 2
      assert first["next_offset"] == 2

      last = conn |> get(~p"/api/follows/followers?limit=2&offset=2") |> json_response(200)
      assert length(last["results"]) == 1
      assert last["next_offset"] == nil

      ids = Enum.map(first["results"] ++ last["results"], & &1["profile_id"])
      assert Enum.sort(ids) == Enum.sort(Enum.map(fans, & &1.id))
    end
  end

  describe "GET /api/follows/search" do
    test "busca por username sem incluir o próprio usuário", %{conn: conn, me: me} do
      {_, other} = profile_fixture()

      %{"results" => results} =
        conn |> get(~p"/api/follows/search?q=user_&limit=50") |> json_response(200)

      ids = Enum.map(results, & &1["profile_id"])
      assert other.id in ids
      refute me.id in ids
    end

    test "busca vazia lista todos em ordem alfabética pelo nome", %{conn: conn, me: me} do
      {_, carla} = profile_fixture(%{full_name: "carla"})
      {_, ana} = profile_fixture(%{full_name: "Ana"})
      {_, bruno} = profile_fixture(%{full_name: "Bruno"})

      %{"results" => results, "next_offset" => nil} =
        conn |> get(~p"/api/follows/search?q=") |> json_response(200)

      ids = Enum.map(results, & &1["profile_id"])
      assert ids == [ana.id, bruno.id, carla.id]
      refute me.id in ids
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
