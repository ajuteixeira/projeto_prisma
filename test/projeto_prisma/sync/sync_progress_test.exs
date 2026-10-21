defmodule ProjetoPrisma.Sync.SyncProgressTest do
  use ExUnit.Case, async: true

  alias ProjetoPrisma.Sync.SyncProgress

  defp profile_id, do: System.unique_integer([:positive])

  defp start_waiting(profile_id) do
    {:ok, :started} =
      SyncProgress.run(profile_id, fn ->
        receive do
          :finish -> :ok
        end
      end)

    SyncProgress.get(profile_id).pid
  end

  test "acumula o progresso dos eventos do SyncService" do
    id = profile_id()
    pid = start_waiting(id)

    for event <- [
          %{type: "sync:start", total: 2},
          %{type: "account:start", account_id: 1, platform: "steam"},
          %{type: "games:total", total_games: 10, platform_id: 1},
          %{
            type: "game:synced",
            current: 3,
            total: 10,
            progress_percent: 30,
            achievements_count: 5
          }
        ] do
      SyncProgress.record(id, event)
    end

    assert %{
             running: true,
             accounts_total: 2,
             current: %{platform: "steam", games_done: 3, games_total: 10}
           } = SyncProgress.get(id)

    SyncProgress.record(id, %{
      type: "account:finished",
      account_id: 1,
      games_synced: 10,
      achievements_synced: 40
    })

    SyncProgress.record(id, %{type: "account:failed", account_id: 2, reason: "x"})

    assert %{
             accounts_done: 2,
             accounts_failed: 1,
             games_synced: 10,
             achievements_synced: 40,
             current: nil
           } = SyncProgress.get(id)

    send(pid, :finish)
  end

  test "recusa uma segunda execução e libera o perfil quando a task termina" do
    id = profile_id()
    pid = start_waiting(id)

    assert {:error, :already_running} = SyncProgress.run(id, fn -> :ok end)

    ref = Process.monitor(pid)
    send(pid, :finish)
    assert_receive {:DOWN, ^ref, :process, ^pid, _}
    _ = :sys.get_state(SyncProgress)

    assert %{running: false, finished_at: %DateTime{}} = SyncProgress.get(id)
    assert {:ok, :started} = SyncProgress.run(id, fn -> :ok end)
  end

  test "ignora eventos sem sincronização ativa" do
    id = profile_id()
    assert :ok = SyncProgress.record(id, %{type: "sync:start", total: 1})
    assert SyncProgress.get(id) == nil
  end
end
