defmodule Mmentum.Repo.Migrations.CreateLogs do
  use Ecto.Migration

  def change do
    create table(:logs) do
      add :user_id, references(:users, on_delete: :nothing)
      add :habit_id, references(:habits, on_delete: :nothing)

      timestamps()
    end

    create index(:logs, [:user_id])
    create index(:logs, [:habit_id])
  end
end
