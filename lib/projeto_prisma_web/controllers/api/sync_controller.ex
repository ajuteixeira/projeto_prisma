defmodule ProjetoPrismaWeb.Api.SyncController do
  use ProjetoPrismaWeb, :controller

  alias ProjetoPrisma.Accounts
  alias ProjetoPrisma.Sync.SyncService
  alias ProjetoPrismaWeb.ApiJSON

  @doc """
  GET /api/sync: estado da sincronização do perfil, no formato de `ApiJSON.sync_status/1`.
  """
  def show(conn, _params) do
    with {:ok, profile} <- current_profile(conn) do
      json(conn, %{sync: ApiJSON.sync_status(SyncService.status(profile.id))})
    else
      {:error, conn} -> conn
    end
  end

  @doc """
  POST /api/sync: inicia em segundo plano a sincronização das contas pendentes.

  Responde `202` com `started: true` ao iniciar, ou `200` com `started: false` se já
  houver uma em andamento ou nenhuma conta pendente. `sync` traz o estado atual.
  """
  def create(conn, _params) do
    with {:ok, profile} <- current_profile(conn) do
      started = SyncService.start_background_sync(profile.id) == {:ok, :started}

      conn
      |> put_status(if(started, do: :accepted, else: :ok))
      |> json(%{started: started, sync: ApiJSON.sync_status(SyncService.status(profile.id))})
    else
      {:error, conn} -> conn
    end
  end

  defp current_profile(conn) do
    case Accounts.get_profile_with_user(conn.assigns.current_scope) do
      nil ->
        {:error,
         conn
         |> put_status(:not_found)
         |> json(%{error: "Perfil nao encontrado"})
         |> halt()}

      profile ->
        {:ok, profile}
    end
  end
end
