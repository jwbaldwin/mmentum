defmodule Mmentum.OAuth.Connection do
  use Ecto.Schema

  @primary_key {:id, :string, autogenerate: false}
  schema "oauth_connections" do
    belongs_to :user, Mmentum.Accounts.User
    field :client_id, :string
    field :refresh_family_id, :string
    field :scopes, {:array, :string}, default: []
    field :revoked_at, :utc_datetime_usec
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end
end
