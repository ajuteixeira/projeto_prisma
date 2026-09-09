defmodule ProjetoPrismaWeb.ApiJSON do
  @moduledoc """
  Serializers JSON compartilhados pelos controllers da API.
  """

  alias ProjetoPrisma.Accounts.{Profile, ProfilePlatformAccount, User}

  def user(%User{} = user) do
    %{
      id: user.id,
      email: user.email,
      username: user.username,
      full_name: user.full_name
    }
  end

  def profile(nil), do: nil

  def profile(%Profile{} = profile) do
    %{
      id: profile.id,
      username: profile.username
    }
  end

  def platform_account(%ProfilePlatformAccount{} = account) do
    %{
      platform: account.platform.slug,
      external_user_id: account.external_user_id,
      profile_url: account.profile_url,
      sync_status: account.sync_status
    }
  end

  def changeset_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
