defmodule ProjetoPrisma.RateLimiter do
  @moduledoc """
  In-memory fixed-window rate limiter backed by ETS.

  This limiter is process-local (single node) and intended for abuse protection
  in web flows such as forgot-password.
  """

  use GenServer

  @table :projeto_prisma_rate_limiter
  @cleanup_interval_ms :timer.minutes(10)

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Increments the counter for `key` inside `window_seconds` and validates against `limit`.

  Returns `:ok` when request is allowed, or `{:error, :rate_limited}` when blocked.
  """
  def check(key, limit, window_seconds)
      when is_integer(limit) and limit > 0 and is_integer(window_seconds) and window_seconds > 0 do
    now = System.system_time(:second)
    window_start = now - window_seconds

    count =
      case :ets.lookup(@table, key) do
        [{^key, timestamps}] ->
          recent = Enum.filter(timestamps, &(&1 > window_start))
          :ets.insert(@table, {key, [now | recent]})
          length(recent) + 1

        [] ->
          :ets.insert(@table, {key, [now]})
          1
      end

    if count > limit, do: {:error, :rate_limited}, else: :ok
  end

  @impl true
  def init(_state) do
    :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    schedule_cleanup()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    now = System.system_time(:second)
    max_window_seconds = :timer.hours(24) |> div(1000)
    threshold = now - max_window_seconds

    for {key, timestamps} <- :ets.tab2list(@table) do
      recent = Enum.filter(timestamps, &(&1 > threshold))

      case recent do
        [] -> :ets.delete(@table, key)
        _ -> :ets.insert(@table, {key, recent})
      end
    end

    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval_ms)
  end
end
