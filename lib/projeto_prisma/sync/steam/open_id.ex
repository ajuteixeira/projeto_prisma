defmodule ProjetoPrisma.Sync.Steam.OpenID do
  @moduledoc """
  Helpers do fluxo OpenID 2.0 da Steam (vinculação de conta).

  A Steam não usa OAuth "clássico": o usuário é redirecionado para o login
  OpenID e retorna para o `return_to` informado, que pode carregar query
  params próprios (ex.: o `state` assinado do fluxo mobile).
  """

  @openid_endpoint "https://steamcommunity.com/openid/login"
  @openid_ns "http://specs.openid.net/auth/2.0"
  @identifier_select "http://specs.openid.net/auth/2.0/identifier_select"

  @doc """
  Monta a URL de login OpenID da Steam com o `return_to` e `realm` informados.
  """
  def authorize_url(return_to, realm) do
    query =
      URI.encode_query(%{
        "openid.ns" => @openid_ns,
        "openid.mode" => "checkid_setup",
        "openid.return_to" => return_to,
        "openid.realm" => realm,
        "openid.identity" => @identifier_select,
        "openid.claimed_id" => @identifier_select
      })

    @openid_endpoint <> "?" <> query
  end

  @doc """
  Verifica a asserção OpenID junto à Steam (`check_authentication`).
  """
  def verify_assertion(params) do
    form_params =
      params
      |> Enum.filter(fn {key, _} -> is_binary(key) and String.starts_with?(key, "openid.") end)
      |> Map.new()
      |> Map.put("openid.mode", "check_authentication")
      |> Enum.to_list()

    case Req.post(@openid_endpoint, form: form_params) do
      {:ok, %{status: 200, body: body}} ->
        if String.contains?(to_string(body), "is_valid:true"),
          do: :ok,
          else: {:error, :assertion_invalid}

      {:ok, %{status: status}} ->
        {:error, {:verify_http_status, status}}

      {:error, _reason} ->
        {:error, :verify_request_failed}
    end
  end
end
