# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Mmentum.Repo.insert!(%Mmentum.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

if Mix.env() == :dev do
  alias Mmentum.Accounts.User
  alias Mmentum.Repo

  email = "demo@example.com"
  password = "TestPassword123"

  changeset =
    case Repo.get_by(User, email: email) do
      nil ->
        User.registration_changeset(%User{}, %{
          email: email,
          full_name: "Demo User",
          password: password
        })

      user ->
        User.password_changeset(user, %{password: password})
    end

  changeset
  |> Ecto.Changeset.put_change(
    :confirmed_at,
    NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
  )
  |> Repo.insert_or_update!()

  IO.puts("Seeded #{email} with password #{password}")
end
