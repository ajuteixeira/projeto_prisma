defmodule ProjetoPrisma.Accounts.Profile do
  use Ecto.Schema
  import Ecto.Changeset

  schema "profiles" do
    field :username, :string
    field :bio, :string
    belongs_to :user, ProjetoPrisma.Accounts.User
    has_one :avatar, ProjetoPrisma.Accounts.ProfileAvatar
  end

  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [:username, :user_id, :bio])
    |> validate_required([:username])
    |> validate_length(:username, min: 3, max: 50)
    |> validate_format(:username, ~r/^[a-zA-Z0-9_]+$/,
      message: "deve conter apenas letras, números e underscores"
    )
    |> validate_length(:bio, max: 160)
    |> unique_constraint(:username)
  end
end
