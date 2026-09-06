defmodule Mmentum.Repo.Migrations.CreateOauthConnections do
  use Ecto.Migration

  def change do
    create table(:oauth_connections, primary_key: false) do
      add :id, :string, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :client_id, :string, null: false
      add :refresh_family_id, :string
      add :scopes, {:array, :string}, default: [], null: false
      add :revoked_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:oauth_connections, [:user_id])
    create unique_index(:oauth_connections, [:refresh_family_id])
  end
end
