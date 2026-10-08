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

  describe "GET /api/profile/stats" do
    test "retorna 401 sem token", %{conn: conn} do
      conn = get(conn, ~p"/api/profile/stats")
      assert %{"error" => _} = json_response(conn, 401)
    end

    test "retorna 404 quando o usuário não tem perfil", %{conn: conn} do
      user = user_fixture()
      token = Accounts.generate_api_token(user)

      conn = conn |> api_conn(token) |> get(~p"/api/profile/stats")
      assert %{"error" => _} = json_response(conn, 404)
    end

    test "perfil sem jogos zera as estatísticas e lista as plataformas em 0%", %{conn: conn} do
      user = user_fixture()
      {:ok, _profile} = Accounts.create_profile_for_user(user)
      token = Accounts.generate_api_token(user)
      steam = platform("Steam", "steam")
      psn = platform("PlayStation Network", "playstation")

      conn = conn |> api_conn(token) |> get(~p"/api/profile/stats")

      assert json_response(conn, 200) == %{
               "stats" => %{
                 "total_achievements" => 0,
                 "avg_completion" => 0,
                 "perfect_games" => 0
               },
               "platform_distribution" => [
                 %{
                   "platform_id" => steam.id,
                   "name" => "Steam",
                   "slug" => "steam",
                   "unlocked" => 0,
                   "percentage" => 0
                 },
                 %{
                   "platform_id" => psn.id,
                   "name" => "PlayStation Network",
                   "slug" => "playstation",
                   "unlocked" => 0,
                   "percentage" => 0
                 }
               ]
             }
    end

    test "calcula conquistas, média de conclusão, jogos perfeitos e troféus por plataforma",
         %{conn: conn} do
      user = user_fixture()
      {:ok, profile} = Accounts.create_profile_for_user(user)
      token = Accounts.generate_api_token(user)

      steam = platform("Steam", "steam")
      psn = platform("PlayStation Network", "playstation")
      xbox = platform("Xbox Live", "xbox")

      # Steam: um jogo 100% (3/3) e outro em 25% (1/4).
      perfect = library(profile, "Hades", steam)
      for _ <- 1..3, do: achievement(perfect.profile_game, perfect.platform_game, [])

      partial = library(profile, "Celeste", steam)
      achievement(partial.profile_game, partial.platform_game, [])

      for _ <- 1..3,
          do: achievement(partial.profile_game, partial.platform_game, achieved: false)

      # PlayStation: 50% (1/2).
      half = library(profile, "Bloodborne", psn)
      achievement(half.profile_game, half.platform_game, [])
      achievement(half.profile_game, half.platform_game, achieved: false)

      # Jogo sem conquistas não entra na média nem conta como perfeito.
      library(profile, "Minecraft", xbox)

      # Conquistas de outro perfil não contam.
      stranger = library(other_profile(), "Hades", steam)
      achievement(stranger.profile_game, stranger.platform_game, [])

      conn = conn |> api_conn(token) |> get(~p"/api/profile/stats")
      json = json_response(conn, 200)

      assert json["stats"] == %{
               "total_achievements" => 5,
               "avg_completion" => 58.3,
               "perfect_games" => 1
             }

      assert Enum.map(
               json["platform_distribution"],
               &{&1["slug"], &1["unlocked"], &1["percentage"]}
             ) ==
               [{"steam", 4, 80.0}, {"playstation", 1, 20.0}, {"xbox", 0, 0}]
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

  describe "GET /api/profile/recently-played" do
    test "retorna 401 sem token", %{conn: conn} do
      conn = get(conn, ~p"/api/profile/recently-played")
      assert %{"error" => _} = json_response(conn, 401)
    end

    test "retorna lista vazia quando nenhum jogo foi jogado", %{conn: conn} do
      user = user_fixture()
      {:ok, _profile} = Accounts.create_profile_for_user(user)
      token = Accounts.generate_api_token(user)

      conn = conn |> api_conn(token) |> get(~p"/api/profile/recently-played")

      assert %{"recently_played" => [], "total" => 0, "limit" => 10, "offset" => 0} =
               json_response(conn, 200)
    end

    test "retorna games jogados recentemente em ordem decrescente", %{conn: conn} do
      user = user_fixture()
      {:ok, profile} = Accounts.create_profile_for_user(user)
      token = Accounts.generate_api_token(user)

      # Criar 3 games
      lib1 = library(profile, "Game 1")
      lib2 = library(profile, "Game 2")
      lib3 = library(profile, "Game 3")

      now = NaiveDateTime.utc_now()
      one_day_ago = NaiveDateTime.add(now, -86400)
      two_days_ago = NaiveDateTime.add(now, -172800)

      # Atualizar last_played para diferentes datas
      lib1.profile_game
      |> ProjetoPrisma.Accounts.ProfileGame.changeset(%{last_played: two_days_ago})
      |> Repo.update!()

      lib2.profile_game
      |> ProjetoPrisma.Accounts.ProfileGame.changeset(%{last_played: one_day_ago})
      |> Repo.update!()

      lib3.profile_game
      |> ProjetoPrisma.Accounts.ProfileGame.changeset(%{last_played: now})
      |> Repo.update!()

      conn = conn |> api_conn(token) |> get(~p"/api/profile/recently-played")

      assert %{"recently_played" => games, "total" => 3} = json_response(conn, 200)
      assert length(games) == 3

      # Verificar que estão em ordem decrescente (Game 3, Game 2, Game 1)
      [game1, game2, game3] = games
      assert game1["game_name"] == "Game 3"
      assert game2["game_name"] == "Game 2"
      assert game3["game_name"] == "Game 1"
    end

    test "respeita limit e offset", %{conn: conn} do
      user = user_fixture()
      {:ok, profile} = Accounts.create_profile_for_user(user)
      token = Accounts.generate_api_token(user)

      for i <- 1..15 do
        lib = library(profile, "Game #{i}")
        lib.profile_game
        |> ProjetoPrisma.Accounts.ProfileGame.changeset(%{
          last_played: NaiveDateTime.add(NaiveDateTime.utc_now(), -i * 3600)
        })
        |> Repo.update!()
      end

      # Primeira página
      conn = conn |> api_conn(token) |> get(~p"/api/profile/recently-played?limit=5&offset=0")
      assert %{"recently_played" => games, "total" => 15, "limit" => 5, "offset" => 0} =
               json_response(conn, 200)
      assert length(games) == 5

      # Segunda página
      conn = build_conn() |> api_conn(token) |> get(~p"/api/profile/recently-played?limit=5&offset=5")
      assert %{"recently_played" => games, "total" => 15, "limit" => 5, "offset" => 5} =
               json_response(conn, 200)
      assert length(games) == 5
    end

    test "formata resposta corretamente com todos os campos", %{conn: conn} do
      user = user_fixture()
      {:ok, profile} = Accounts.create_profile_for_user(user)
      token = Accounts.generate_api_token(user)

      lib = library(profile, "Test Game")

      now = NaiveDateTime.utc_now()
      lib.profile_game
      |> ProjetoPrisma.Accounts.ProfileGame.changeset(%{
        last_played: now,
        playtime_minutes: 240
      })
      |> Repo.update!()

      conn = conn |> api_conn(token) |> get(~p"/api/profile/recently-played")

      assert %{"recently_played" => [game]} = json_response(conn, 200)

      # Precarregar para verificação
      platform_game = Repo.preload(lib.platform_game, [:platform, :game])

      assert game["id"] == lib.profile_game.id
      assert game["game_name"] == "Test Game"
      assert game["platform"] == platform_game.platform.slug
      assert game["playtime_minutes"] == 240
      assert is_binary(game["last_played"])
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

  defp platform(name, slug) do
    %Platform{} |> Platform.changeset(%{name: name, slug: slug}) |> Repo.insert!()
  end

  defp library(profile, game_name, on_platform \\ nil) do
    id = unique_integer()
    platform = on_platform || platform("Platform #{id}", "platform-#{id}")

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
      achieved: Keyword.get(attrs, :achieved, true),
      pinned_position: Keyword.get(attrs, :pinned_position)
    })
    |> Repo.insert!()
  end

  defp unique_integer, do: System.unique_integer([:positive])
end
