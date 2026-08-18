defmodule Mmentum.Repo.Migrations.RemoveCachedMomentumFromHabits do
  use Ecto.Migration

  def change do
    alter table(:habits) do
      remove :momentum_score, :float, default: 0.0, null: false
      remove :momentum_last_updated, :bigint
    end
  end
end
