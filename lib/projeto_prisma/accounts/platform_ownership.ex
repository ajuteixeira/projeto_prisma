defmodule ProjetoPrisma.Accounts.PlatformOwnership do
  @moduledoc """
  Vinculação por prova de posse das plataformas sem OAuth (PSN e RetroAchievements).

  As credenciais sozinhas não provam que a conta informada é do usuário: qualquer
  NPSSO/API Key consulta qualquer perfil público. Por isso o usuário cola um código
  `PRISMA-XXXX` no "Sobre Mim" (PSN) ou no "Motto" (RetroAchievements) e só
  vinculamos quando o código aparece no perfil consultado.
  """

  alias ProjetoPrisma.Accounts
  alias ProjetoPrisma.Sync.RetroAchievements.Client, as: RetroClient
  alias ProjetoPrisma.Utils.Psn.Psn_Auth
  alias ProjetoPrisma.Utils.Psn.Psn_Profile

  @code_chars ~c"ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

  @doc """
  Gera um código de verificação no formato `PRISMA-XXXX` (sem 0/O/1/I).
  """
  def generate_code do
    suffix = for _ <- 1..4, into: "", do: <<Enum.random(@code_chars)>>
    "PRISMA-" <> suffix
  end

  @doc """
  Valida as credenciais, confere o código no perfil e vincula a conta.

  Retorna `{:ok, %ProfilePlatformAccount{}}` ou `{:error, reason}`, onde `reason`
  é um dos átomos tratados por `error_message/2`.
  """
  def connect(profile_id, "playstation", psn_id, npsso, code) do
    with {:ok, auth} <- psn_authenticate(npsso),
         {:ok, profile} <- psn_profile(auth.access_token, psn_id),
         :ok <- check_code(profile.about_me, code) do
      Accounts.connect_platform_account(profile_id, "playstation", %{
        "external_user_id" => profile.account_id,
        "profile_url" => "",
        "api_key" => npsso
      })
    end
  end

  def connect(profile_id, "retroachievements", username, api_key, code) do
    with {:ok, body} <- retro_profile(username, api_key),
         :ok <- check_code(body["Motto"], code) do
      Accounts.connect_platform_account(profile_id, "retroachievements", %{
        "external_user_id" => username,
        "profile_url" => "https://retroachievements.org/user/#{username}",
        "api_key" => api_key
      })
    end
  end

  def connect(_profile_id, _slug, _username, _api_key, _code), do: {:error, :platform_not_found}

  @doc """
  Mensagem exibida ao usuário para cada falha de `connect/5`.
  """
  def error_message("playstation", :verification_code_missing),
    do:
      "Não encontramos o código de verificação no seu 'Sobre Mim'. Cole o código no seu perfil PlayStation, salve e aguarde alguns segundos antes de tentar novamente."

  def error_message("retroachievements", :verification_code_missing),
    do:
      "Não encontramos o código de verificação no campo 'Motto' do seu perfil RetroAchievements. Cole o código, salve e tente novamente."

  def error_message("playstation", :invalid_credentials),
    do:
      "Token de Acesso inválido ou expirado. Gere um novo em ca.account.sony.com/api/v1/ssocookie"

  def error_message("retroachievements", :invalid_credentials),
    do: "Falha na validação. Confira Username e API Key"

  def error_message("playstation", :account_not_found),
    do: "PSN ID não encontrado. Verifique se o nome de usuário está correto."

  def error_message("playstation", :request_failed),
    do: "Não foi possível validar com a API da PSN agora"

  def error_message("retroachievements", :request_failed),
    do: "Não foi possível validar com a API do RetroAchievements agora"

  def error_message("retroachievements", {:http_status, status}),
    do: "RetroAchievements respondeu com status #{status}. Verifique os dados e tente novamente"

  def error_message(_slug, :platform_not_found),
    do: "Plataforma não encontrada no banco. Rode o seed para cadastrar as plataformas."

  def error_message(_slug, _reason), do: "Não foi possível salvar a conexão"

  defp psn_authenticate(npsso) do
    case Psn_Auth.authenticate(npsso) do
      {:ok, auth} -> {:ok, auth}
      {:error, _reason} -> {:error, :invalid_credentials}
    end
  end

  # `Psn_Profile` devolve o erro como texto ("PSN erro 404: ...").
  defp psn_profile(access_token, psn_id) do
    case Psn_Profile.get_profile_from_username(access_token, psn_id) do
      {:ok, profile} -> {:ok, profile}
      {:error, "PSN erro 404" <> _} -> {:error, :account_not_found}
      {:error, "PSN erro 401" <> _} -> {:error, :invalid_credentials}
      {:error, _reason} -> {:error, :request_failed}
    end
  end

  defp retro_profile(username, api_key) do
    case RetroClient.get_player_profile(username, api_key) do
      {:ok, %{status: 200, body: body}} when is_map(body) and body != %{} -> {:ok, body}
      {:ok, %{status: 200}} -> {:error, :invalid_credentials}
      {:ok, %{status: 401}} -> {:error, :invalid_credentials}
      {:ok, %{status: status}} -> {:error, {:http_status, status}}
      {:error, _reason} -> {:error, :request_failed}
    end
  end

  defp check_code(text, code) when is_binary(text) and is_binary(code) do
    if String.contains?(text, code), do: :ok, else: {:error, :verification_code_missing}
  end

  defp check_code(_text, _code), do: {:error, :verification_code_missing}
end
