defmodule ProjetoPrismaWeb.Api.FollowController do
  use ProjetoPrismaWeb, :controller

  alias ProjetoPrisma.Accounts
  alias ProjetoPrismaWeb.ApiJSON

  @doc """
  GET /api/follows — as listas da página Seguidores da web: quem segue o
  usuário e quem ele segue, mais recentes primeiro.
  """
  def index(conn, _params) do
    with_profile(conn, fn profile ->
      following_ids = following_ids(profile.id)

      json(conn, %{
        followers: serialize(Accounts.list_followers(profile.id), following_ids),
        following: serialize(Accounts.list_following(profile.id), following_ids)
      })
    end)
  end

  @doc """
  GET /api/follows/search?q= — busca por username, sem o próprio usuário,
  como a aba Pesquisar da web. Busca vazia não retorna ninguém.
  """
  def search(conn, params) do
    with_profile(conn, fn profile ->
      results = Accounts.search_profiles_by_username(profile.id, params["q"] || "")
      json(conn, %{results: serialize(results, following_ids(profile.id))})
    end)
  end

  @doc "PUT /api/follows/:profile_id — segue o perfil (idempotente)."
  def follow(conn, %{"profile_id" => raw_id}) do
    with_target(conn, raw_id, fn profile, target_id ->
      case Accounts.follow_profile(profile.id, target_id) do
        :ok ->
          send_resp(conn, :no_content, "")

        {:error, :cannot_follow_self} ->
          error(conn, :unprocessable_entity, "Voce nao pode seguir seu proprio perfil.")

        {:error, _reason} ->
          error(conn, :unprocessable_entity, "Nao foi possivel atualizar o follow agora.")
      end
    end)
  end

  @doc "DELETE /api/follows/:profile_id — deixa de seguir o perfil (idempotente)."
  def unfollow(conn, %{"profile_id" => raw_id}) do
    with_target(conn, raw_id, fn profile, target_id ->
      :ok = Accounts.unfollow_profile(profile.id, target_id)
      send_resp(conn, :no_content, "")
    end)
  end

  defp with_profile(conn, fun) do
    case Accounts.get_profile_with_user(conn.assigns.current_scope) do
      nil -> error(conn, :not_found, "Perfil nao encontrado")
      profile -> fun.(profile)
    end
  end

  defp with_target(conn, raw_id, fun) do
    with_profile(conn, fn profile ->
      case Integer.parse(to_string(raw_id)) do
        {target_id, ""} ->
          if Accounts.get_profile(target_id),
            do: fun.(profile, target_id),
            else: error(conn, :not_found, "Perfil nao encontrado")

        _ ->
          error(conn, :bad_request, "Perfil invalido para seguir.")
      end
    end)
  end

  defp following_ids(profile_id), do: MapSet.new(Accounts.list_following_ids(profile_id))

  defp serialize(profiles, following_ids),
    do: Enum.map(profiles, &ApiJSON.follow_profile(&1, following_ids))

  defp error(conn, status, message) do
    conn |> put_status(status) |> json(%{error: message})
  end
end
