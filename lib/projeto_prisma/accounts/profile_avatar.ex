defmodule ProjetoPrisma.Accounts.ProfileAvatar do
  use Ecto.Schema
  import Ecto.Changeset

  schema "profile_avatars" do
    field :data, :string
    field :content_type, :string
    belongs_to :profile, ProjetoPrisma.Accounts.Profile

    timestamps()
  end

  def changeset(avatar, attrs) do
    avatar
    |> cast(attrs, [:data, :content_type, :profile_id])
    |> validate_required([:data, :content_type, :profile_id])
    |> unique_constraint(:profile_id)
  end
end
