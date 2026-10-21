defmodule ProjetoPrisma.SyncRunnerStub do
  @moduledoc """
  Substitui `SyncService.run_pending/1` nos testes. Termina ao receber `:finish` ou após 5 s.
  """

  def run_pending(_profile_id) do
    receive do
      :finish -> :ok
    after
      5_000 -> :ok
    end
  end
end
