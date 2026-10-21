defmodule ProjetoPrismaWeb.Api.SyncControllerTest do
  use ProjetoPrismaWeb.ConnCase, async: true

  import ProjetoPrisma.AccountsFixtures

  alias ProjetoPrisma.Accounts
  alias ProjetoPrisma.Catalog.Platform
  alias ProjetoPrisma.Repo
  alias ProjetoPrisma.Sync.SyncProgress

  setup %{conn: conn} do
    user = user_fixture()
    {:ok, profile} = Accounts.create_profile_for_user(user)
    token = Accounts.generate_api_token(user)

    %{conn: put_req_header(conn, "authorization", "Bearer #{token}"), profile: profile}
  end

  defp connect_steam(profile) do
    {:ok, _platform} =
      %Platform{}
      |> Platform.changeset(%{name: "Steam", slug: "steam"})
      |> Repo.insert()

    {:ok, account} =
      Accounts.connect_platform_account(profile.id, "steam", %{
        "external_user_id" => "76561198000000000",
        "api_key" => "steam-key"
      })

    account
  end

  defp finish_sync(profile_id) do
    %{pid: pid} = SyncProgress.get(profile_id)
    ref = Process.monitor(pid)
    send(pid, :finish)
    assert_receive {:DOWN, ^ref, :process, ^pid, _}
    _ = :sys.get_state(SyncProgress)
  end

  describe "GET /api/sync" do
    test "retorna 401 sem token" do
      conn = get(build_conn(), ~p"/api/sync")
      assert %{"error" => _} = json_response(conn, 401)
    end

    test "sem sincronização desde o boot, responde parado e zerado", %{conn: conn} do
      conn = get(conn, ~p"/api/sync")

      assert %{
               "sync" => %{
                 "running" => false,
                 "accounts_total" => 0,
                 "games_synced" => 0,
                 "current" => nil,
                 "platforms" => []
               }
             } = json_response(conn, 200)
    end

    test "traz o status salvo de cada conta", %{conn: conn, profile: profile} do
      connect_steam(profile)

      conn = get(conn, ~p"/api/sync")

      assert %{"sync" => %{"platforms" => [%{"platform" => "steam", "sync_status" => "idle"}]}} =
               json_response(conn, 200)
    end
  end

  describe "POST /api/sync" do
    test "sem contas pendentes, não inicia", %{conn: conn} do
      conn = post(conn, ~p"/api/sync")
      assert %{"started" => false, "sync" => %{"running" => false}} = json_response(conn, 200)
    end

    test "inicia a sincronização das contas pendentes", %{conn: conn, profile: profile} do
      connect_steam(profile)

      conn = post(conn, ~p"/api/sync")
      assert %{"started" => true, "sync" => %{"running" => true}} = json_response(conn, 202)

      finish_sync(profile.id)
    end

    test "não duplica uma sincronização em andamento", %{conn: conn, profile: profile} do
      connect_steam(profile)

      assert %{"started" => true} = conn |> post(~p"/api/sync") |> json_response(202)

      assert %{"started" => false, "sync" => %{"running" => true}} =
               conn |> post(~p"/api/sync") |> json_response(200)

      finish_sync(profile.id)

      assert %{"sync" => %{"running" => false, "finished_at" => finished_at}} =
               conn |> get(~p"/api/sync") |> json_response(200)

      assert is_binary(finished_at)
    end
  end
end
