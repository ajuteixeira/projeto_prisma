defmodule ProjetoPrisma.Accounts do
  @moduledoc """
  Context para gerenciar profiles de usuários e suas contas em plataformas.

  Encapsula lógica de criar/buscar profiles, contas de plataforma,
  e games/achievements sincronizados do usuário.
  """

  import Ecto.Query
  alias ProjetoPrisma.Repo
  alias ProjetoPrisma.Accounts.{User, Profile, ProfilePlatformAccount, ProfileGame, ProfileAchievement}
  alias ProjetoPrisma.Catalog.Platform

  @doc """
  Registra um novo usuário com senha hasheada.

  ## Parâmetros
    - `attrs` - %{email: "user@example.com", password: "secret123", username: "john_doe", full_name: "John Doe"}

  ## Exemplos
      iex> register_user(%{email: "user@example.com", password: "secret123", username: "john_doe"})
      {:ok, %User{}}
  """
  def register_user_legacy(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Cria um profile vinculado a um usuário.

  ## Parâmetros
    - `user` - %User{} com id e username

  ## Exemplos
      iex> create_profile_for_user(user)
      {:ok, %Profile{}}
  """
  def create_profile_for_user(user) do
    %Profile{}
    |> Profile.changeset(%{username: user.username, user_id: user.id})
    |> Repo.insert()
  end

  @doc """
  Autentica um usuário por email e senha.

  ## Parâmetros
    - `email` - Email do usuário
    - `password` - Senha em texto plano

  ## Exemplos
      iex> authenticate_user("user@example.com", "secret123")
      {:ok, %User{}}

      iex> authenticate_user("user@example.com", "wrong_password")
      {:error, :invalid_password}
  """
  def authenticate_user(email, password) do
    user = Repo.get_by(User, email: String.downcase(String.trim(email)))

    cond do
      user && User.valid_password?(user, password) ->
        {:ok, user}
      user ->
        {:error, :invalid_password}
      true ->
        Bcrypt.no_user_verify()
        {:error, :not_found}
    end
  end

  @doc """
  Busca um usuário pelo email.

  ## Exemplos
      iex> get_user_by_email("user@example.com")
      %User{} | nil
  """
  def get_user_by_email(email) do
    Repo.get_by(User, email: String.downcase(String.trim(email)))
  end

  @doc """
  Redefine a senha de um usuário pelo email.
  """
  def reset_user_password_by_email(email, new_password) do
    case get_user_by_email(email) do
      nil ->
        {:error, :not_found}

      user ->
        user
        |> User.password_reset_changeset(%{password: new_password})
        |> Repo.update()
    end
  end

  @doc """
  Busca um usuário pelo ID e precarrega o profile.

  ## Exemplos
      iex> get_user_with_profile(1)
      %User{profile: %Profile{}}
  """
  def get_user_with_profile(user_id) do
    User
    |> Repo.get(user_id)
    |> Repo.preload(:profile)
  end

  @doc """
  Busca ou cria um profile.

  ## Parâmetros
    - `attrs` - %{username: "john_doe"}

  ## Exemplos
      iex> get_or_create_profile(%{username: "john_doe"})
      {:ok, %Profile{}}
  """
  def get_or_create_profile(attrs) do
    username = attrs["username"] || attrs[:username]

    case Repo.get_by(Profile, username: username) do
      nil ->
        %Profile{}
        |> Profile.changeset(attrs)
        |> Repo.insert()

      profile ->
        {:ok, profile}
    end
  end

  @doc """
  Busca um profile pelo ID.

  ## Exemplos
      iex> get_profile(1)
      %Profile{} | nil
  """
  def get_profile(profile_id) do
    Repo.get(Profile, profile_id)
  end

  @doc """
  Busca um profile pelo username.

  ## Exemplos
      iex> get_profile_by_username("fulano")
      %Profile{} | nil
  """
  def get_profile_by_username(username) when is_binary(username) do
    normalized = String.downcase(String.trim(username))

    Profile
    |> where([p], fragment("lower(?)", p.username) == ^normalized)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Busca ou cria uma conta de usuário em uma plataforma.

  ## Parâmetros
    - `profile_id` - ID do perfil
    - `platform_id` - ID da plataforma
    - `attrs` - %{external_user_id: "76561198310494902", profile_url: "..."}

  ## Exemplos
      iex> get_or_create_platform_account(1, 1, %{external_user_id: "12345", profile_url: "..."})
      {:ok, %ProfilePlatformAccount{}}
  """
  def get_or_create_platform_account(profile_id, platform_id, attrs) do
    case Repo.get_by(ProfilePlatformAccount,
           profile_id: profile_id,
           platform_id: platform_id
         ) do
      nil ->
        %ProfilePlatformAccount{}
        |> ProfilePlatformAccount.changeset(
          Map.merge(attrs, %{
            "profile_id" => profile_id,
            "platform_id" => platform_id
          })
        )
        |> Repo.insert()

      account ->
        {:ok, account}
    end
  end

  @doc """
  Busca uma conta de plataforma de um usuário.

  ## Exemplos
      iex> get_platform_account(profile_id, platform_id)
      %ProfilePlatformAccount{} | nil
  """
  def get_platform_account(profile_id, platform_id) do
    Repo.get_by(ProfilePlatformAccount,
      profile_id: profile_id,
      platform_id: platform_id
    )
  end

  @doc """
  Lista os slugs das plataformas conectadas para um profile.

  ## Exemplos
      iex> list_connected_platform_slugs(1)
      ["steam", "xbox"]
  """
  def list_connected_platform_slugs(profile_id) do
    ProfilePlatformAccount
    |> join(:inner, [ppa], p in Platform, on: p.id == ppa.platform_id)
    |> where([ppa, _p], ppa.profile_id == ^profile_id)
    |> select([_ppa, p], p.slug)
    |> distinct(true)
    |> Repo.all()
  end

  @doc """
  Conecta uma conta de plataforma por slug para um profile.

  Retorna `{:ok, %ProfilePlatformAccount{}}` quando já existe ou quando cria.
  """
  def connect_platform_account(profile_id, platform_slug, attrs) do
    case Repo.get_by(Platform, slug: platform_slug) do
      nil ->
        {:error, :platform_not_found}

      platform ->
        get_or_create_platform_account(profile_id, platform.id, attrs)
    end
  end

  @doc """
  Desconecta uma conta de plataforma por slug de um profile.

  Retorna `{:ok, :not_connected}` caso não exista vínculo.
  """
  def disconnect_platform_account(profile_id, platform_slug) do
    with %Platform{} = platform <- Repo.get_by(Platform, slug: platform_slug) do
      case Repo.get_by(ProfilePlatformAccount, profile_id: profile_id, platform_id: platform.id) do
        nil -> {:ok, :not_connected}
        account -> Repo.delete(account)
      end
    else
      nil -> {:error, :platform_not_found}
    end
  end

  @doc """
  Busca ou cria um game na biblioteca do usuário.

  ## Parâmetros
    - `profile_id` - ID do perfil
    - `platform_game_id` - ID do PlatformGame
    - `attrs` - %{playtime_minutes: 100, last_played: NaiveDateTime}

  ## Exemplos
      iex> get_or_create_profile_game(1, 1, %{playtime_minutes: 100, last_played: ~N[2025-03-15 10:00:00]})
      {:ok, %ProfileGame{}}
  """
  def get_or_create_profile_game(profile_id, platform_game_id, attrs) do
    case Repo.get_by(ProfileGame,
           profile_id: profile_id,
           platform_game_id: platform_game_id
         ) do
      nil ->
        %ProfileGame{}
        |> ProfileGame.changeset(
          Map.merge(attrs, %{
            "profile_id" => profile_id,
            "platform_game_id" => platform_game_id
          })
        )
        |> Repo.insert()

      profile_game ->
        # Se já existe, atualiza com novos dados
        profile_game
        |> ProfileGame.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Busca ou cria um achievement desbloqueado pelo usuário.

  ## Parâmetros
    - `profile_game_id` - ID do ProfileGame
    - `achievement_id` - ID do Achievement
    - `attrs` - %{achieved: true, unlock_time: NaiveDateTime}

  ## Exemplos
      iex> get_or_create_profile_achievement(1, 1, %{achieved: true, unlock_time: ~N[2025-03-15 10:00:00]})
      {:ok, %ProfileAchievement{}}
  """
  def get_or_create_profile_achievement(profile_game_id, achievement_id, attrs) do
    case Repo.get_by(ProfileAchievement,
           profile_game_id: profile_game_id,
           achievement_id: achievement_id
         ) do
      nil ->
        %ProfileAchievement{}
        |> ProfileAchievement.changeset(
          Map.merge(attrs, %{
            "profile_game_id" => profile_game_id,
            "achievement_id" => achievement_id
          })
        )
        |> Repo.insert()

      profile_achievement ->
        # Se já existe, atualiza (caso tenha desbloqueado agora)
        profile_achievement
        |> ProfileAchievement.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Lista todos os games de um usuário em uma plataforma.

  ## Exemplos
      iex> list_user_games(1, 1)
      [%ProfileGame{}, ...]
  """
  def list_user_games(profile_id, platform_id) do
    ProfileGame
    |> where([pg], pg.profile_id == ^profile_id)
    |> preload(:platform_game)
    |> Repo.all()
    |> Enum.filter(fn pg -> pg.platform_game.platform_id == platform_id end)
  end

  @doc """
  Conta quantos achievements um usuário desbloqueou em um game.

  ## Exemplos
      iex> count_user_achievements(profile_game_id)
      42
  """
  def count_user_achievements(profile_game_id) do
    ProfileAchievement
    |> where([pa], pa.profile_game_id == ^profile_game_id and pa.achieved == true)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Retorna dados de sincronização de um usuário em uma plataforma.

  ## Exemplos
      iex> get_sync_account_data(profile_id, platform_id)
      %{profile: %Profile{}, platform_account: %ProfilePlatformAccount{}, games: [...]}
  """
  def get_sync_account_data(profile_id, platform_id) do
    profile = get_profile(profile_id)
    platform_account = get_platform_account(profile_id, platform_id)
    games = list_user_games(profile_id, platform_id)

    %{
      profile: profile,
      platform_account: platform_account,
      games: games
    }
  end

  alias ProjetoPrisma.Accounts.{UserToken, UserNotifier}

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.email_changeset(attrs)
    |> Repo.insert()
  end

  ## Settings

  @doc """
  Checks whether the user is in sudo mode.

  The user is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.
  """
  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_user, _minutes), do: false

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  See `ProjetoPrisma.Accounts.User.email_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}, opts \\ []) do
    User.email_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    Repo.transact(fn ->
      with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- Repo.one(query),
           {:ok, user} <- Repo.update(User.email_changeset(user, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(from(UserToken, where: [user_id: ^user.id, context: ^context])) do
        {:ok, user}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  See `ProjetoPrisma.Accounts.User.password_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}, opts \\ []) do
    User.password_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user password.

  Returns a tuple with the updated user, as well as a list of expired tokens.

  ## Examples

      iex> update_user_password(user, %{password: ...})
      {:ok, {%User{}, [...]}}

      iex> update_user_password(user, %{password: "too short"})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> update_user_and_delete_all_tokens()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Gets the user with the given magic link token.
  """
  def get_user_by_magic_link_token(token) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {user, _token} <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Logs the user in by magic link.

  There are three cases to consider:

  1. The user has already confirmed their email. They are logged in
     and the magic link is expired.

  2. The user has not confirmed their email and no password is set.
     In this case, the user gets confirmed, logged in, and all tokens -
     including session ones - are expired. In theory, no other tokens
     exist but we delete all of them for best security practices.

  3. The user has not confirmed their email but a password is set.
     This cannot happen in the default implementation but may be the
     source of security pitfalls. See the "Mixing magic link and password registration" section of
     `mix help phx.gen.auth`.
  """
  def login_user_by_magic_link(token) do
    {:ok, query} = UserToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      # Prevent session fixation attacks by disallowing magic links for unconfirmed users with password
      {%User{confirmed_at: nil, hashed_password: hash}, _token} when not is_nil(hash) ->
        raise """
        magic link log in is not allowed for unconfirmed users with a password set!

        This cannot happen with the default implementation, which indicates that you
        might have adapted the code to a different use case. Please make sure to read the
        "Mixing magic link and password registration" section of `mix help phx.gen.auth`.
        """

      {%User{confirmed_at: nil} = user, _token} ->
        user
        |> User.confirm_changeset()
        |> update_user_and_delete_all_tokens()

      {user, token} ->
        Repo.delete!(token)
        {:ok, {user, []}}

      nil ->
        {:error, :not_found}
    end
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm-email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Delivers the magic link login instructions to the given user.
  """
  def deliver_login_instructions(%User{} = user, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    Repo.insert!(user_token)
    UserNotifier.deliver_login_instructions(user, magic_link_url_fun.(encoded_token))
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  ## Token helper

  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, user} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(UserToken, user_id: user.id)

        Repo.delete_all(from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end
end
