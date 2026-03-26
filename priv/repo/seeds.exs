# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     ProjetoPrisma.Repo.insert!(%ProjetoPrisma.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias ProjetoPrisma.Repo
alias ProjetoPrisma.Accounts.Profile
alias ProjetoPrisma.Catalog.Platform

platforms = [
  %{name: "Steam", slug: "steam"},
  %{name: "PlayStation Network", slug: "playstation"},
  %{name: "Xbox Live", slug: "xbox"},
  %{name: "RetroAchievements", slug: "retroachievements"}
]

Enum.each(platforms, fn attrs ->
  case Repo.get_by(Platform, slug: attrs.slug) do
    nil ->
      %Platform{}
      |> Platform.changeset(attrs)
      |> Repo.insert!()

    _platform ->
      :ok
  end
end)

case Repo.get_by(Profile, username: "Fulano") do
  nil ->
    %Profile{}
    |> Profile.changeset(%{username: "Fulano"})
    |> Repo.insert!()

  _profile ->
    :ok
end
