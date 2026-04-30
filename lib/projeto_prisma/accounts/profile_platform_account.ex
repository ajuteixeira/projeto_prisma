defmodule ProjetoPrisma.Accounts.ProfilePlatformAccount do
  use Ecto.Schema
  import Ecto.Changeset

  alias ProjetoPrisma.Accounts.Profile
  alias ProjetoPrisma.Catalog.Platform

  schema "profile_platform_accounts" do
    field :external_user_id, :string
    field :profile_url, :string
    field :api_key, :string
    field :sync_status, :string, default: "idle"
    field :sync_step, :string
    field :sync_last_error, :string
    field :sync_started_at, :naive_datetime
    field :sync_finished_at, :naive_datetime
    field :sync_attempts, :integer, default: 0

    belongs_to :profile, Profile
    belongs_to :platform, Platform
  end

  def changeset(account, attrs) do
    account
    |> cast(attrs, [
      :external_user_id,
      :profile_url,
      :profile_id,
      :platform_id,
      :api_key,
      :sync_status,
      :sync_step,
      :sync_last_error,
      :sync_started_at,
      :sync_finished_at,
      :sync_attempts
    ])
    |> validate_required([:external_user_id, :profile_id, :platform_id, :api_key])
    |> unique_constraint([:profile_id, :platform_id])
  end
end
