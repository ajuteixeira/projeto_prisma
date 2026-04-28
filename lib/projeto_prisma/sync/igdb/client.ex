defmodule ProjetoPrisma.Sync.Igdb.Client do
  @moduledoc """
  Cliente HTTP para IGDB com autenticação Twitch.

  Responsabilidades:
  - Autenticação com Twitch (token)
  - Cache em memória do access token
  - Requisições HTTP brutas para endpoints da IGDB

  Retorna respostas britas sem normalização.
  """

  @auth_url "https://id.twitch.tv/oauth2/token"
  @api_url "https://api.igdb.com/v4"
  @cache_table :projeto_prisma_igdb_token_cache
  @cache_key :access_token
  @token_buffer_seconds 60

  @doc """
  Faz requisição bruta para um endpoint da IGDB.

  Retorna {:ok, %{status: 200, body: [...]}} ou {:error, reason}
  """
  def request(resource, query) when is_atom(resource) and is_binary(query) do
    with {:ok, access_token} <- get_access_token() do
      Req.post("#{@api_url}/#{resource}",
        headers: [
          {"Client-ID", client_id()},
          {"Authorization", "Bearer #{access_token}"},
          {"Content-Type", "text/plain"}
        ],
        body: query
      )
    end
  end

  @doc """
  Obtém um access token válido da Twitch.

  O token é reaproveitado enquanto estiver dentro da janela de validade.
  """
  def get_access_token do
    ensure_cache_table!()

    case cached_token() do
      {:ok, token, expires_at} ->
        if token_valid?(expires_at) do
          {:ok, token}
        else
          fetch_and_cache_access_token()
        end

      _ ->
        fetch_and_cache_access_token()
    end
  end

  defp fetch_and_cache_access_token do
    with {:ok, %{status: 200, body: body}} <-
           Req.post(@auth_url,
             form: [
               client_id: client_id(),
               client_secret: client_secret(),
               grant_type: "client_credentials"
             ]
           ),
         token when is_binary(token) <- get_body_value(body, "access_token"),
         expires_in when is_integer(expires_in) <- get_body_value(body, "expires_in") do
      expires_at = token_expires_at(expires_in)

      :ets.insert(@cache_table, {@cache_key, token, expires_at})

      {:ok, token}
    else
      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}

      _ ->
        {:error, :invalid_token_response}
    end
  end

  defp cached_token do
    case :ets.lookup(@cache_table, @cache_key) do
      [{@cache_key, token, expires_at}] -> {:ok, token, expires_at}
      [] -> :miss
    end
  end

  defp token_valid?(expires_at) when is_integer(expires_at) do
    DateTime.to_unix(DateTime.utc_now()) < expires_at
  end

  defp token_expires_at(expires_in) when is_integer(expires_in) do
    now = DateTime.to_unix(DateTime.utc_now())
    buffer = min(@token_buffer_seconds, max(expires_in - 1, 0))

    now + max(expires_in - buffer, 0)
  end

  defp ensure_cache_table! do
    case :ets.whereis(@cache_table) do
      :undefined ->
        try do
          :ets.new(@cache_table, [:named_table, :public, :set, read_concurrency: true])
        rescue
          ArgumentError ->
            :ok
        end

      _ ->
        :ok
    end
  end

  defp client_id do
    System.fetch_env!("IGDB_CLIENT_ID")
  end

  defp client_secret do
    System.fetch_env!("IGDB_CLIENT_SECRET")
  end

  defp get_body_value(body, key) when is_map(body) do
    Map.get(body, key) || Map.get(body, String.to_existing_atom(key)) || Map.get(body, String.to_atom(key))
  rescue
    ArgumentError ->
      Map.get(body, key)
  end

  defp get_body_value(_, _), do: nil
end
