defmodule Mmentum.Repo.Migrations.ReplaceStreaksWithMomentum do
  use Ecto.Migration

  def change do
    alter table(:habits) do
      # Remove streak fields
      remove :current_streak
      remove :longest_streak
      remove :last_completed_at
      remove :streak_updated_at

      add :momentum_score, :float, default: 0.0, null: false
      add :momentum_last_updated, :bigint
    end
  end
end
