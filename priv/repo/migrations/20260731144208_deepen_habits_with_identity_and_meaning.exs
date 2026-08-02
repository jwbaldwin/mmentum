defmodule Mmentum.Repo.Migrations.DeepenHabitsWithIdentityAndMeaning do
  use Ecto.Migration

  def change do
    alter table(:habits) do
      add :identity, :text
      add :why_it_matters, :text
      add :what_counts, :text
    end
  end
end
