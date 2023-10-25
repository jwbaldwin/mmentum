defmodule Mmentum.Repo.Migrations.CreateHabits do
  use Ecto.Migration

  def change do
    create table(:habits) do
      add :name, :string
      add :periodicity, :string
      add :iterations, :integer

      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end
  end
end
