defmodule Mmentum.Repo.Migrations.AddStreakFieldsToHabits do
  use Ecto.Migration

  def change do
    alter table(:habits) do
      add :current_streak, :integer, default: 0, null: false
      add :longest_streak, :integer, default: 0, null: false
      add :last_completed_at, :naive_datetime
      add :streak_updated_at, :naive_datetime
    end
  end
end
