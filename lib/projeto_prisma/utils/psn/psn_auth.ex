defmodule ProjetoPrisma.Utils.Psn.Psn_Auth do
  @auth_base_url "https://ca.account.sony.com/api/authz/v3/oauth"

  @client_id "09515159-7237-4370-9b40-3806e67c0891"
  @redirect_uri "com.scee.psxandroid.scecompcall://redirect"
  @basic_auth "Basic MDk1MTUxNTktNzIzNy00MzcwLTliNDAtMzgwNmU2N2MwODkxOnVjUGprYTV0bnRCMktxc1A="

  @doc """
  Troca o NPSSO token por um access code.

  O NPSSO pode ser obtido em: https://ca.account.sony.com/api/v1/ssocookie
  """
  @spec exchange_npsso_for_access_code(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def exchange_npsso_for_access_code(npsso_token) do
    query =
      URI.encode_query(%{
        access_type: "offline",
        client_id: @client_id,
        redirect_uri: @redirect_uri,
        response_type: "code",
        scope: "psn:mobile.v2.core psn:clientapp"
      })

    url = "#{@auth_base_url}/authorize?#{query}"

    case Req.get(url,
           headers: [{"Cookie", "npsso=#{npsso_token}"}],
           redirect: false
         ) do
      {:ok, %{status: status, headers: headers}} when status in [302, 303] ->
        location = get_header(headers, "location")
        extract_code_from_location(location)

      {:ok, _} ->
        {:error, "Problema ao obter o access code. Verifique se o NPSSO é válido. " <>
          "Para obter um novo NPSSO, acesse https://ca.account.sony.com/api/v1/ssocookie"}

      {:error, reason} ->
        {:error, "Erro na requisição: #{inspect(reason)}"}
    end
  end

  @doc """
  Troca o access code por tokens de autenticação (access token, refresh token, etc).
  """
  @spec exchange_access_code_for_auth_tokens(String.t()) :: {:ok, map()} | {:error, String.t()}
  def exchange_access_code_for_auth_tokens(access_code) do
    url = "#{@auth_base_url}/token"

    body =
      URI.encode_query(%{
        code: access_code,
        redirect_uri: @redirect_uri,
        grant_type: "authorization_code",
        token_format: "jwt"
      })

    case Req.post(url,
           headers: [
             {"Content-Type", "application/x-www-form-urlencoded"},
             {"Authorization", @basic_auth}
           ],
           body: body
         ) do
      {:ok, %{status: 200, body: raw}} ->
        {:ok,
         %{
           access_token: raw["access_token"],
           expires_in: raw["expires_in"],
           id_token: raw["id_token"],
           refresh_token: raw["refresh_token"],
           refresh_token_expires_in: raw["refresh_token_expires_in"],
           scope: raw["scope"],
           token_type: raw["token_type"]
         }}

      {:ok, %{status: status, body: body}} ->
        {:error, "Erro #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Erro na requisição: #{inspect(reason)}"}
    end
  end

  @doc """
  Fluxo completo: NPSSO -> access code -> tokens de autenticação.
  """
  @spec authenticate(String.t()) :: {:ok, map()} | {:error, String.t()}
  def authenticate(npsso_token) do
    with {:ok, access_code} <- exchange_npsso_for_access_code(npsso_token),
         {:ok, auth_tokens} <- exchange_access_code_for_auth_tokens(access_code) do
      {:ok, auth_tokens}
    end
  end

  # --- Privadas ---

  defp get_header(headers, name) do
    case Map.fetch(headers, name) do
      {:ok, [value | _]} -> value
      {:ok, value} -> value
      :error -> nil
    end
  end

  defp extract_code_from_location(location) do
    if String.contains?(location, "code=") do
      location
      |> URI.parse()
      |> Map.get(:query)
      |> URI.decode_query()
      |> Map.fetch("code")
      |> case do
        {:ok, code} -> {:ok, code}
        :error -> {:error, "Parâmetro 'code' não encontrado na URL de redirect"}
      end
    else
      {:error, "URL de redirect não contém o access code. NPSSO pode ser inválido."}
    end
  end
end
