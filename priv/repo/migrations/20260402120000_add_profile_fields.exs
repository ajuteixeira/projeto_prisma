defmodule ProjetoPrisma.Repo.Migrations.AddProfileFields do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      add :display_name, :string
      add :avatar_url, :string
      add :bio, :string
    end
  end
end
