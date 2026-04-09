defmodule ProjetoPrisma.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :full_name, :string
    field :username, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :utc_datetime
    field :authenticated_at, :utc_datetime, virtual: true

    has_one :profile, ProjetoPrisma.Accounts.Profile

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset legado para cadastro completo (username/full_name + senha).
  """
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password, :full_name, :username])
    |> validate_required([:email, :password, :username])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "deve ter formato valido")
    |> validate_length(:password, min: 6, message: "deve ter no minimo 6 caracteres")
    |> validate_length(:username, min: 3, message: "deve ter no minimo 3 caracteres")
    |> validate_format(:username, ~r/^[a-z0-9_]+$/, message: "apenas letras, numeros e underscore")
    |> unsafe_validate_unique(:email, ProjetoPrisma.Repo)
    |> unique_constraint(:email)
    |> unsafe_validate_unique(:username, ProjetoPrisma.Repo)
    |> unique_constraint(:username)
    |> put_password_hash()
  end

  @doc """
  A user changeset for registering or changing the email.

  It requires the email to change otherwise an error is added.

  ## Options

    * `:validate_unique` - Set to false if you don't want to validate the
      uniqueness of the email, useful when displaying live validations.
      Defaults to `true`.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
  end

  defp validate_email(changeset, opts) do
    changeset =
      changeset
      |> validate_required([:email], message: "nao pode ficar em branco")
      |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
        message: "deve conter @ e nao ter espacos"
      )
      |> validate_length(:email, max: 160, message: "deve ter no maximo 160 caracteres")

    if Keyword.get(opts, :validate_unique, true) do
      changeset
      |> unsafe_validate_unique(:email, ProjetoPrisma.Repo)
      |> unique_constraint(:email)
      |> validate_email_changed()
    else
      changeset
    end
  end

  defp validate_email_changed(changeset) do
    if get_field(changeset, :email) && get_change(changeset, :email) == nil do
      add_error(changeset, :email, "nao foi alterado")
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the password.

  It is important to validate the length of the password, as long passwords may
  be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "nao coincide com a senha")
    |> validate_password(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password], message: "nao pode ficar em branco")
    |> validate_length(:password,
      min: 12,
      max: 72,
      message: "deve ter entre 12 e 72 caracteres"
    )
    # Examples of additional password validation:
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # If using Bcrypt, then further validate it is at most 72 bytes long
      |> validate_length(:password, max: 72, count: :bytes)
      # Hashing could be done with `Ecto.Changeset.prepare_changes/2`, but that
      # would keep the database transaction open longer and hurt performance.
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = DateTime.utc_now(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%ProjetoPrisma.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  defp put_password_hash(changeset) do
  def password_reset_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_length(:password, min: 6, message: "deve ter no minimo 6 caracteres")
    |> hash_password()
  end

  defp hash_password(changeset) do
    case get_change(changeset, :password) do
      nil ->
        changeset

      password when changeset.valid? ->
        hash = Bcrypt.hash_pwd_salt(password)

        changeset
        |> put_change(:hashed_password, hash)

      _ ->
        changeset
    end
  end
end
