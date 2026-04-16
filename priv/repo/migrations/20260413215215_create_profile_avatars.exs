defmodule ProjetoPrisma.Repo.Migrations.CreateProfileAvatars do
  use Ecto.Migration

  def change do
    create table(:profile_avatars) do
      add :profile_id, references(:profiles, on_delete: :delete_all), null: false
      add :data, :text, null: false
      add :content_type, :string, null: false

      timestamps()
    end

    create unique_index(:profile_avatars, [:profile_id])
  end
end
