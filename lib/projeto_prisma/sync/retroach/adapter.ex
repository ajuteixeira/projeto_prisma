defmodule ProjetoPrisma.Adapter.RetroAchAdapter do
  alias ProjetoPrisma.Client.RetroAchClient

  @spec fetch_games(String.t(), keyword()) :: [map()]
  def fetch_games(username, opts \\ []) when is_binary(username) and is_list(opts) do
    username
    |> RetroAchClient.get_owned_games(opts)
    |> decode_body()
    |> Enum.reject(&hardcore_mode?/1)
    |> Enum.map(&normalize_game/1)
  end

  @spec normalize_game(map()) :: map()
  def normalize_game(%{
        "GameID" => game_id,
        "Title" => title,
        "ImageIcon" => image_icon,
        "ConsoleName" => console_name
      }) do
    %{
      external_game_id: to_string(game_id),
      game: %{
        name: title,
        cover_image: image_icon,
        icon_image: image_icon,
        logo_image: nil
      },
      platform: %{
        name: console_name,
        slug: slugify(console_name)
      }
    }
  end

  defp hardcore_mode?(%{"HardcoreMode" => "1"}), do: true
  defp hardcore_mode?(_), do: false

  defp decode_body(body) when is_binary(body), do: Jason.decode!(body)
  defp decode_body(body), do: body

  defp slugify(name) when is_binary(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
  end

end
