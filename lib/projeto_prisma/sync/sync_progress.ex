defmodule ProjetoPrisma.Sync.SyncProgress do
  @moduledoc """
  Estado em memória (ETS) da sincronização de cada perfil.

  Permite uma sincronização ativa por perfil e mantém o estado da última
  execução até a próxima começar.
  """

  use GenServer

  @table __MODULE__

  def start_link(_opts), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  @doc """
  Executa `fun` em uma task do `SyncTaskSupervisor` e marca o perfil como em
  sincronização até a task terminar.

  Retorna `{:ok, :started}` ou `{:error, :already_running}`.
  """
  def run(profile_id, fun) when is_function(fun, 0) do
    GenServer.call(__MODULE__, {:run, profile_id, fun})
  end

  @doc """
  Estado da execução mais recente do perfil. Retorna `nil` se nenhuma rodou desde o boot.
  """
  def get(profile_id) do
    case :ets.lookup(@table, profile_id) do
      [{^profile_id, entry}] -> entry
      [] -> nil
    end
  end

  @doc """
  Atualiza o estado do perfil com um evento de `SyncService`. Ignora o evento se o
  perfil não tiver sincronização ativa. `sync:start` soma ao total de contas, pois
  uma execução pode ter várias rodadas.
  """
  def record(profile_id, event) do
    case get(profile_id) do
      %{running: true} = entry -> :ets.insert(@table, {profile_id, apply_event(entry, event)})
      _ -> :ok
    end

    :ok
  end

  @impl true
  def init(_) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    {:ok, %{}}
  end

  @impl true
  def handle_call({:run, profile_id, fun}, _from, refs) do
    case get(profile_id) do
      %{running: true} ->
        {:reply, {:error, :already_running}, refs}

      _ ->
        {:ok, pid} = Task.Supervisor.start_child(ProjetoPrisma.SyncTaskSupervisor, fun)
        ref = Process.monitor(pid)
        :ets.insert(@table, {profile_id, new_entry(pid)})
        {:reply, {:ok, :started}, Map.put(refs, ref, profile_id)}
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, refs) do
    {profile_id, refs} = Map.pop(refs, ref)

    with %{} = entry <- profile_id && get(profile_id) do
      :ets.insert(@table, {profile_id, finish(entry)})
    end

    {:noreply, refs}
  end

  defp new_entry(pid) do
    %{
      pid: pid,
      running: true,
      started_at: now(),
      finished_at: nil,
      accounts_total: 0,
      accounts_done: 0,
      accounts_failed: 0,
      games_synced: 0,
      achievements_synced: 0,
      current: nil
    }
  end

  defp finish(entry), do: %{entry | running: false, current: nil, finished_at: now()}

  defp apply_event(entry, %{type: "sync:start", total: total}),
    do: %{entry | accounts_total: entry.accounts_total + total}

  defp apply_event(entry, %{type: "account:start", platform: platform}),
    do: %{entry | current: %{platform: platform, games_done: 0, games_total: nil}}

  defp apply_event(%{current: %{} = current} = entry, %{type: "games:total", total_games: total}),
    do: %{entry | current: %{current | games_total: total}}

  defp apply_event(%{current: %{} = current} = entry, %{type: type, current: done})
       when type in ["game:synced", "game:failed"],
       do: %{entry | current: %{current | games_done: done}}

  defp apply_event(entry, %{type: "account:finished"} = event) do
    %{
      entry
      | accounts_done: entry.accounts_done + 1,
        games_synced: entry.games_synced + event.games_synced,
        achievements_synced: entry.achievements_synced + event.achievements_synced,
        current: nil
    }
  end

  defp apply_event(entry, %{type: "account:failed"}) do
    %{
      entry
      | accounts_done: entry.accounts_done + 1,
        accounts_failed: entry.accounts_failed + 1,
        current: nil
    }
  end

  defp apply_event(entry, _event), do: entry

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
