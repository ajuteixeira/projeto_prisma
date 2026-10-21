defmodule ProjetoPrismaWeb.Api.FollowController do
  use ProjetoPrismaWeb, :controller

  alias ProjetoPrisma.Accounts
  alias ProjetoPrismaWeb.ApiJSON

  # Tamanho de página padrão e máximo das listas paginadas.
  @page_size 20
  @max_page_size 50

  @doc """
  GET /api/follows — as contagens das abas Seguidores e Seguindo. As listas
  vêm paginadas de `/api/follows/followers` e `/api/follows/following`.
  """
  def index(conn, _params) do
    with_profile(conn, fn profile ->
      json(conn, %{
        followers_count: Accounts.count_profile_followers(profile.id),
        following_count: Accounts.count_profile_following(profile.id)
      })
    end)
  end

  @doc "GET /api/follows/followers?offset=&limit= — quem segue o usuário, mais recentes primeiro."
  def followers(conn, params),
    do: page(conn, params, &Accounts.list_followers(&1.id, &2))

  @doc "GET /api/follows/following?offset=&limit= — quem o usuário segue, mais recentes primeiro."
  def following(conn, params),
    do: page(conn, params, &Accounts.list_following(&1.id, &2))

  @doc """
  GET /api/follows/search?q=&offset=&limit= — todos os perfis, sem o próprio
  usuário, em ordem alfabética pelo nome; `q` filtra por username.
  """
  def search(conn, params),
    do: page(conn, params, &Accounts.list_profiles_by_name(&1.id, params["q"] || "", &2))

  # Busca uma página a mais para saber se há próxima; `next_offset` é `nil` no fim.
  defp page(conn, params, fetch) do
    with_profile(conn, fn profile ->
      offset = parse_int(params["offset"], 0, 0, nil)
      limit = parse_int(params["limit"], @page_size, 1, @max_page_size)
      {results, rest} = profile |> fetch.(offset: offset, limit: limit + 1) |> Enum.split(limit)

      json(conn, %{
        results: serialize(results, following_ids(profile.id)),
        next_offset: if(rest == [], do: nil, else: offset + limit)
      })
    end)
  end

  defp parse_int(raw, default, min, max) do
    case Integer.parse(to_string(raw || "")) do
      {value, ""} when value >= min -> if max, do: min(value, max), else: value
      _ -> default
    end
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
