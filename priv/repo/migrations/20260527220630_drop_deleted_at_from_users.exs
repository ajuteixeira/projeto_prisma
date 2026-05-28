defmodule ProjetoPrisma.Repo.Migrations.DropDeletedAtFromUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove :deleted_at, :utc_datetime, default: nil
    end
  end
end
