defmodule ProjetoPrisma.Repo.Migrations.RemoveLegacyAvatarAndDisplayNameFromProfiles do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      remove :avatar_data, :text
      remove :avatar_url, :string
      remove :display_name, :string
    end
  end
end
