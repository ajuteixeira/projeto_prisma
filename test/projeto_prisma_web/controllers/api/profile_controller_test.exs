defmodule ProjetoPrismaWeb.Api.ProfileControllerTest do
  use ProjetoPrismaWeb.ConnCase, async: true

  import ProjetoPrisma.AccountsFixtures

  alias ProjetoPrisma.Accounts
  alias ProjetoPrisma.Accounts.{ProfileAchievement, ProfileAvatar, ProfileFollow, ProfileGame}
  alias ProjetoPrisma.Catalog.{Achievement, Game, Platform, PlatformGame}
  alias ProjetoPrisma.Repo

  defp api_conn(conn, token) do
    put_req_header(conn, "authorization", "Bearer #{token}")
  end

  describe "GET /api/profile" do
    test "retorna 401 sem token", %{conn: conn} do
      conn = get(conn, ~p"/api/profile")
      assert %{"error" => _} = json_response(conn, 401)
    end

    test "retorna 404 quando o usuário não tem perfil", %{conn: conn} do
      user = user_fixture()
      token = Accounts.generate_api_token(user)

      conn = conn |> api_conn(token) |> get(~p"/api/profile")
      assert %{"error" => _} = json_response(conn, 404)
    end

    test "retorna o cartão de perfil vazio de um usuário novo", %{conn: conn} do
      user = user_fixture()
      {:ok, profile} = Accounts.create_profile_for_user(user)
      token = Accounts.generate_api_token(user)

      conn = conn |> api_conn(token) |> get(~p"/api/profile")

      assert json_response(conn, 200) == %{
               "profile" => %{
                 "id" => profile.id,
                 "username" => profile.username,
                 "bio" => nil,
                 "avatar_url" => nil,
                 "followers_count" => 0,
                 "following_count" => 0,
                 "pinned_achievements" => []
               }
             }
    end

    test "retorna bio, avatar, contagem de seguidores e conquistas fixadas", %{conn: conn} do
      user = user_fixture()
      {:ok, profile} = Accounts.create_profile_for_user(user)

      {:ok, profile} =
        profile |> Ecto.Changeset.change(bio: "Caçadora de platina") |> Repo.update()

      token = Accounts.generate_api_token(user)

      avatar = "data:image/png;base64,iVBORw0KGgo="

      %ProfileAvatar{}
      |> ProfileAvatar.changeset(%{
        profile_id: profile.id,
        data: avatar,
        content_type: "image/png"
      })
      |> Repo.insert!()

      [fan_a, fan_b, idol] = for _ <- 1..3, do: other_profile()
      follow(fan_a, profile)
      follow(fan_b, profile)
      follow(profile, idol)

      %{profile_game: profile_game, platform_game: platform_game} = library(profile, "Hades")

      second =
        achievement(profile_game, platform_game,
          name: "Fantasma",
          icon_image: "https://example.com/fantasma.png",
          pinned_position: 2
        )

      first =
        achievement(profile_game, platform_game,
          name: "Mestre Atirador",
          icon_image: "https://example.com/mestre.png",
          pinned_position: 1
        )

      # Nem as não fixadas nem as fixadas de outro perfil aparecem no cartão.
      achievement(profile_game, platform_game, name: "Não fixada")
      other = other_profile()
      %{profile_game: other_game, platform_game: other_platform_game} = library(other, "Doom")
      achievement(other_game, other_platform_game, pinned_position: 1)

      conn = conn |> api_conn(token) |> get(~p"/api/profile")

      assert %{"profile" => json} = json_response(conn, 200)
      assert json["bio"] == "Caçadora de platina"
      assert json["avatar_url"] == avatar
      assert json["followers_count"] == 2
      assert json["following_count"] == 1

      assert json["pinned_achievements"] == [
               %{
                 "id" => first.id,
                 "name" => "Mestre Atirador",
                 "game_name" => "Hades",
                 "icon_url" => "https://example.com/mestre.png",
                 "position" => 1
               },
               %{
                 "id" => second.id,
                 "name" => "Fantasma",
                 "game_name" => "Hades",
                 "icon_url" => "https://example.com/fantasma.png",
                 "position" => 2
               }
             ]
    end

    test "ignora avatar salvo fora do formato data URL", %{conn: conn} do
      user = user_fixture()
      {:ok, profile} = Accounts.create_profile_for_user(user)
      token = Accounts.generate_api_token(user)

      %ProfileAvatar{}
      |> ProfileAvatar.changeset(%{
        profile_id: profile.id,
        data: "lixo",
        content_type: "image/png"
      })
      |> Repo.insert!()

      conn = conn |> api_conn(token) |> get(~p"/api/profile")

      assert %{"profile" => %{"avatar_url" => nil}} = json_response(conn, 200)
    end
  end

  defp other_profile do
    user = user_fixture()
    {:ok, profile} = Accounts.create_profile_for_user(user)
    profile
  end

  defp follow(follower, followed) do
    %ProfileFollow{}
    |> ProfileFollow.changeset(%{
      follower_profile_id: follower.id,
      followed_profile_id: followed.id
    })
    |> Repo.insert!()
  end

  defp library(profile, game_name) do
    id = unique_integer()

    platform =
      %Platform{}
      |> Platform.changeset(%{name: "Platform #{id}", slug: "platform-#{id}"})
      |> Repo.insert!()

    game = %Game{} |> Game.changeset(%{name: game_name}) |> Repo.insert!()

    platform_game =
      %PlatformGame{}
      |> PlatformGame.changeset(%{
        platform_id: platform.id,
        game_id: game.id,
        external_game_id: "game-#{id}"
      })
      |> Repo.insert!()

    profile_game =
      %ProfileGame{}
      |> ProfileGame.changeset(%{profile_id: profile.id, platform_game_id: platform_game.id})
      |> Repo.insert!()

    %{platform_game: platform_game, profile_game: profile_game}
  end

  defp achievement(profile_game, platform_game, attrs) do
    id = unique_integer()

    achievement =
      %Achievement{}
      |> Achievement.changeset(%{
        platform_game_id: platform_game.id,
        external_achievement_id: "achievement-#{id}",
        name: Keyword.get(attrs, :name, "Achievement #{id}"),
        icon_image: Keyword.get(attrs, :icon_image)
      })
      |> Repo.insert!()

    %ProfileAchievement{}
    |> ProfileAchievement.changeset(%{
      profile_game_id: profile_game.id,
      achievement_id: achievement.id,
      achieved: true,
      pinned_position: Keyword.get(attrs, :pinned_position)
    })
    |> Repo.insert!()
  end

  defp unique_integer, do: System.unique_integer([:positive])
end
