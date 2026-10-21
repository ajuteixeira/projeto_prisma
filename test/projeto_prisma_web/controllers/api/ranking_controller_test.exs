defmodule ProjetoPrismaWeb.Api.RankingControllerTest do
  use ProjetoPrismaWeb.ConnCase, async: true

  import ProjetoPrisma.AccountsFixtures

  alias ProjetoPrisma.Accounts
  alias ProjetoPrisma.Accounts.ProfileFollow
  alias ProjetoPrisma.Repo

  defp api_conn(conn, token), do: put_req_header(conn, "authorization", "Bearer #{token}")

  test "retorna 401 sem token", %{conn: conn} do
    assert %{"error" => _} = conn |> get(~p"/api/ranking") |> json_response(401)
  end

  test "retorna 404 quando o usuário não tem perfil", %{conn: conn} do
    token = Accounts.generate_api_token(user_fixture())

    assert %{"error" => _} =
             conn |> api_conn(token) |> get(~p"/api/ranking") |> json_response(404)
  end

  test "inclui o usuário e quem ele segue", %{conn: conn} do
    user = user_fixture()
    {:ok, profile} = Accounts.create_profile_for_user(user)
    {:ok, friend} = Accounts.create_profile_for_user(user_fixture())

    %ProfileFollow{}
    |> ProfileFollow.changeset(%{follower_profile_id: profile.id, followed_profile_id: friend.id})
    |> Repo.insert!()

    token = Accounts.generate_api_token(user)

    %{"ranking" => ranking} =
      conn |> api_conn(token) |> get(~p"/api/ranking") |> json_response(200)

    assert ranking |> Enum.map(& &1["profile_id"]) |> Enum.sort() ==
             Enum.sort([profile.id, friend.id])

    me = Enum.find(ranking, & &1["is_current_user"])

    assert me == %{
             "profile_id" => profile.id,
             "username" => profile.username,
             "avatar_url" => nil,
             "achievement_count" => 0,
             "platform_counts" => %{},
             "platforms" => [],
             "is_current_user" => true
           }
  end
end
