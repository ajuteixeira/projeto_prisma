alias ProjetoPrisma.{Accounts, Repo}
alias ProjetoPrisma.Accounts.User

email = "teste@teste.com"
password = "teste123123"
username = "teste"

user =
  case Repo.get_by(User, email: email) do
    nil ->
      {:ok, u} =
        Accounts.register_user_legacy(%{
          "email" => email,
          "password" => password,
          "username" => username,
          "full_name" => "Conta de Teste"
        })

      IO.puts("Usuario criado: #{u.email}")
      u

    existing ->
      IO.puts("Usuario ja existe: #{existing.email}")
      existing
  end

confirmed =
  user
  |> User.confirm_changeset()
  |> Repo.update!()

IO.puts("Confirmado em: #{confirmed.confirmed_at}")

case Accounts.create_profile_for_user(confirmed) do
  {:ok, profile} -> IO.puts("Profile criado: #{profile.username}")
  {:error, %Ecto.Changeset{errors: errors}} -> IO.inspect(errors, label: "Profile (ja existia ou erro)")
end

IO.puts("\nLogin: #{email} / #{password}")
