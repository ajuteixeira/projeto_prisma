defmodule ProjetoPrismaWeb.PageController do
  use ProjetoPrismaWeb, :controller

  alias ProjetoPrisma.Accounts
  alias ProjetoPrisma.Accounts.Scope
  alias ProjetoPrisma.Sync.SyncService
  alias ProjetoPrismaWeb.UserAuth

  def home(conn, _params) do
    render(conn, :home)
  end

  def connect_platforms(conn, _params) do
    render(conn, :connect_platforms)
  end

  def profile(conn, _params) do
    conn = prepare_dashboard_sync(conn)
    profile_session = profile_live_session(conn, conn.assigns[:profile_id], false)

    conn
    |> assign(:show_navbar, nil)
    |> assign(:show_sync, true)
    |> assign(:show_view_navbar, false)
    |> assign(:profile_session, profile_session)
    |> render(:profile)
  end

  def friend_profile(conn, %{"username" => username}) do
    case Accounts.get_profile_with_user_by_username(username) do
      %{} = profile ->
        read_only = read_only_profile?(conn.assigns[:current_scope], profile)

        conn =
          if read_only do
            conn
            |> assign(:profile_id, profile.id)
            |> assign(:sync_popup, nil)
          else
            prepare_dashboard_sync(conn)
          end

        profile_session = profile_live_session(conn, profile.id, read_only)

        conn
        |> assign(:show_navbar, not read_only)
        |> assign(:show_sync, not read_only)
        |> assign(:show_view_navbar, read_only)
        |> assign(:profile_session, profile_session)
        |> render(:profile)

      _ ->
        conn
        |> put_flash(:error, "Perfil nao encontrado.")
        |> redirect(to: ~p"/followers")
    end
  end

  def followers(conn, _params) do
    render(conn, :followers)
  end

  def ranking(conn, _params) do
    render(conn, :ranking)
  end

  def register(conn, _params) do
    redirect(conn, to: ~p"/users/register")
  end

  def complete_registration(conn, %{"token" => token}) do
    case Phoenix.Token.verify(ProjetoPrismaWeb.Endpoint, "registration", token, max_age: 300) do
      {:ok, %{user_id: user_id, profile_id: profile_id}} ->
        user = Accounts.get_user!(user_id)

        conn
        |> put_session(:user_return_to, "/connect-platforms")
        |> UserAuth.log_in_user(user)
        |> put_session(:profile_id, profile_id)
        |> put_flash(:info, "Conta criada com sucesso!")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Link de registro expirado ou invalido")
        |> redirect(to: ~p"/users/register")
    end
  end

  def complete_registration(conn, _params) do
    conn
    |> put_flash(:error, "Token de registro invalido")
    |> redirect(to: ~p"/users/register")
  end

  defp prepare_dashboard_sync(conn) do
    case resolve_profile_id_from_conn(conn) do
      {:ok, profile_id} ->
        sync_popup = dashboard_sync_popup(profile_id)

        conn
        |> assign(:profile_id, profile_id)
        |> assign(:sync_popup, sync_popup)
        |> maybe_start_dashboard_sync(profile_id, sync_popup)

      _ ->
        assign(conn, :sync_popup, nil)
    end
  end

  defp maybe_start_dashboard_sync(conn, _profile_id, %{status: :running}), do: conn
  defp maybe_start_dashboard_sync(conn, _profile_id, %{status: :failed}), do: conn

  defp maybe_start_dashboard_sync(conn, profile_id, %{status: :idle}) do
    _ = Task.start(fn -> SyncService.sync_connected_platforms(profile_id) end)

    assign(conn, :sync_popup, %{
      status: :running,
      title: "Sincronizando suas contas",
      message: "Atualizando jogos e troféus em segundo plano.",
      progress: true,
      count: nil
    })
  end

  defp maybe_start_dashboard_sync(conn, _profile_id, _), do: conn

  defp dashboard_sync_popup(profile_id) do
    accounts = Accounts.list_connected_platform_accounts(profile_id)
    running_accounts = Enum.filter(accounts, &(&1.sync_status == "running"))
    failed_accounts = Enum.filter(accounts, &(&1.sync_status == "failed"))

    cond do
      running_accounts != [] ->
        %{
          status: :running,
          title: "Sincronização em andamento",
          message: "Estamos atualizando jogos e troféus agora.",
          progress: true,
          count: length(running_accounts)
        }

      failed_accounts != [] ->
        %{
          status: :failed,
          title: "Sincronização interrompida",
          message: "Algumas contas falharam e podem ser retomadas depois.",
          progress: false,
          count: length(failed_accounts)
        }

      accounts != [] ->
        %{
          status: :idle,
          title: "Sincronização iniciando",
          message: "Preparando atualização de jogos e troféus.",
          progress: true,
          count: length(accounts)
        }

      true ->
        nil
    end
  end

  defp resolve_profile_id_from_conn(conn) do
    case conn.assigns[:current_scope] do
      %Scope{} = scope ->
        case Accounts.get_profile_with_user(scope) do
          %{id: profile_id} when is_integer(profile_id) -> {:ok, profile_id}
          _ -> :error
        end

      _ ->
        case get_session(conn, :profile_id) do
          profile_id when is_integer(profile_id) -> {:ok, profile_id}
          _ -> :error
        end
    end
  end

  defp profile_live_session(conn, profile_id, read_only) do
    base = %{
      "user_token" => get_session(conn, :user_token),
      "read_only" => read_only
    }

    if is_integer(profile_id) do
      Map.put(base, "profile_id", profile_id)
    else
      base
    end
  end

  defp read_only_profile?(%Scope{user: %{id: user_id}}, %{user_id: profile_user_id})
       when is_integer(user_id) and is_integer(profile_user_id) do
    user_id != profile_user_id
  end

  defp read_only_profile?(_scope, _profile), do: true
end
