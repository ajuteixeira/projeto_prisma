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

  describe "PATCH /api/profile" do
    setup do
      user = user_fixture()
      {:ok, user} = Accounts.update_user_full_name(user_scope_fixture(user), "Carly")
      {:ok, profile} = Accounts.create_profile_for_user(user)
      %{user: user, profile: profile, token: Accounts.generate_api_token(user)}
    end

    test "retorna 401 sem token", %{conn: conn} do
      conn = patch(conn, ~p"/api/profile", %{"bio" => "oi"})
      assert %{"error" => _} = json_response(conn, 401)
    end

    test "atualiza nome, nickname e bio e devolve o cartão e o usuário", %{
      conn: conn,
      user: user,
      profile: profile,
      token: token
    } do
      conn =
        conn
        |> api_conn(token)
        |> patch(~p"/api/profile", %{
          "full_name" => "Carly Mendes",
          "username" => "carly_nova",
          "bio" => "Platina é vida."
        })

      assert %{"profile" => profile_json, "user" => user_json} = json_response(conn, 200)
      assert profile_json["username"] == "carly_nova"
      assert profile_json["bio"] == "Platina é vida."
      assert profile_json["followers_count"] == 0

      assert user_json == %{
               "id" => user.id,
               "email" => user.email,
               "username" => "carly_nova",
               "full_name" => "Carly Mendes"
             }

      assert Repo.get!(ProjetoPrisma.Accounts.User, user.id).username == "carly_nova"
      assert Repo.get!(ProjetoPrisma.Accounts.Profile, profile.id).username == "carly_nova"
    end

    test "campos ausentes ficam como estão; bio vazia é apagada", %{
      conn: conn,
      user: user,
      profile: profile,
      token: token
    } do
      profile |> Ecto.Changeset.change(bio: "Antiga") |> Repo.update!()

      conn = conn |> api_conn(token) |> patch(~p"/api/profile", %{"bio" => ""})

      assert %{
               "profile" => %{"bio" => nil, "username" => username},
               "user" => %{"full_name" => "Carly"}
             } =
               json_response(conn, 200)

      assert username == user.username
    end

    test "salva o avatar enviado como data URL", %{conn: conn, token: token} do
      avatar = "data:image/png;base64," <> Base.encode64("png-bytes")

      conn = conn |> api_conn(token) |> patch(~p"/api/profile", %{"avatar" => avatar})

      assert %{"profile" => %{"avatar_url" => ^avatar}} = json_response(conn, 200)
    end

    test "recusa avatar fora dos formatos aceitos", %{conn: conn, token: token} do
      avatar = "data:image/bmp;base64," <> Base.encode64("bmp")

      conn = conn |> api_conn(token) |> patch(~p"/api/profile", %{"avatar" => avatar})

      assert %{"errors" => %{"avatar" => [_]}} = json_response(conn, 422)
    end

    test "recusa avatar maior que 2 MB", %{conn: conn, token: token} do
      avatar = "data:image/jpeg;base64," <> Base.encode64(:binary.copy("a", 2_000_001))

      conn = conn |> api_conn(token) |> patch(~p"/api/profile", %{"avatar" => avatar})

      assert %{"errors" => %{"avatar" => [_]}} = json_response(conn, 422)
    end

    test "recusa nickname em uso sem alterar nada", %{
      conn: conn,
      user: user,
      token: token
    } do
      other = user_fixture()

      conn =
        conn
        |> api_conn(token)
        |> patch(~p"/api/profile", %{
          "username" => String.upcase(other.username),
          "bio" => "Não deve salvar"
        })

      assert %{"errors" => %{"username" => [_]}} = json_response(conn, 422)
      assert Repo.get!(ProjetoPrisma.Accounts.User, user.id).username == user.username
      assert Repo.get_by!(ProjetoPrisma.Accounts.Profile, user_id: user.id).bio == nil
    end

    test "valida formato do nickname, tamanho do nome e da bio", %{conn: conn, token: token} do
      conn =
        conn
        |> api_conn(token)
        |> patch(~p"/api/profile", %{
          "username" => "com espaço",
          "full_name" => "ab",
          "bio" => String.duplicate("a", 91)
        })

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Map.keys(errors) |> Enum.sort() == ["bio", "full_name", "username"]
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
