defmodule Mmentum.Repo.Migrations.EnforceHabitCompletionRange do
  use Ecto.Migration

  def change do
    create constraint(:habits, :habits_completion_range,
             check: "max_completions IS NULL OR max_completions > min_completions"
           )
  end
end
