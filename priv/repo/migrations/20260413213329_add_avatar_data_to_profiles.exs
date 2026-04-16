defmodule ProjetoPrisma.Repo.Migrations.AddAvatarDataToProfiles do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      add :avatar_data, :text
    end
  end
end
