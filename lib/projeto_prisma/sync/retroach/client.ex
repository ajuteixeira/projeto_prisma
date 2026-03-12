defmodule ProjetoPrisma.Client.RetroAchClient do
  alias Req.Response

  @default_base_url "https://retroachievements.org/API"

  @spec get_owned_games(String.t(), keyword()) :: any()
  def get_owned_games(username, opts \\ []) when is_binary(username) and is_list(opts) do
    base_url = base_url()
    api_key =
      case Keyword.fetch(opts, :api_key) do
        {:ok, value} -> value
        :error -> api_key!()
      end

    "#{base_url}/API_GetUserCompletedGames.php"
    |> Req.get!(params: [y: api_key, u: username])
    |> extract_body()
  end

  defp extract_body(%Response{body: body}), do: body

  defp base_url do
    :projeto_prisma
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:base_url, @default_base_url)
  end

  defp api_key! do
    :projeto_prisma
    |> Application.fetch_env!(__MODULE__)
    |> Keyword.fetch!(:api_key)
  end
end
