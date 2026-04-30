defmodule ProjetoPrisma.Repo.Migrations.AddMissingSyncColumnsToProfilePlatformAccounts do
  use Ecto.Migration

  def change do
    alter table(:profile_platform_accounts) do
      add :sync_status, :string, null: false, default: "idle"
      add :sync_step, :string
      add :sync_last_error, :text
      add :sync_started_at, :naive_datetime
      add :sync_finished_at, :naive_datetime
      add :sync_attempts, :integer, null: false, default: 0
    end
  end
end
