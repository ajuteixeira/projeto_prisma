defmodule ProjetoPrismaWeb.PlatformConnect do
  @moduledoc """
  Token de estado assinado para o fluxo de vinculação de plataformas via API.

  Como o app mobile não compartilha a sessão web, o `state` do OAuth/OpenID
  carrega um `Phoenix.Token` de curta duração com o `profile_id` (e, no caso
  da Steam, a `api_key`) para que o callback saiba a qual perfil vincular.
  """

  @salt "platform-connect"
  @max_age_in_seconds 600

  def sign(payload) when is_map(payload) do
    Phoenix.Token.sign(ProjetoPrismaWeb.Endpoint, @salt, payload)
  end

  def verify(token) when is_binary(token) do
    Phoenix.Token.verify(ProjetoPrismaWeb.Endpoint, @salt, token, max_age: @max_age_in_seconds)
  end

  def verify(_token), do: :error

  @doc """
  URL de retorno para o app mobile após a vinculação (sucesso ou erro).
  """
  def deep_link_url(status, platform, message \\ nil) do
    base = Application.get_env(:projeto_prisma, :mobile_deep_link, "prisma://connect")

    query =
      %{status: status, platform: platform, message: message}
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> URI.encode_query()

    base <> "?" <> query
  end
end
