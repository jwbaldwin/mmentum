defmodule Mmentum.Habits.Momentum do
  @moduledoc """
  Momentum score system for habit tracking.

  Uses continuous momentum scoring instead of binary streaks. The score represents 
  "momentum" - it rises with each completion and naturally decays over time, creating 
  a fluid representation of habit consistency.
  """

  @max_score 100.0
  @milliseconds_per_day 86_400_000

  @doc """
  Calculates the current momentum score by applying exponential decay from last update.

  ## Parameters
  - `score`: Previous momentum score (0-100)
  - `last_updated`: Unix timestamp in milliseconds when score was last updated
  - `current_time`: Current Unix timestamp in milliseconds
  - `half_life_days`: Number of days for score to decay by 50%

  ## Formula
  S(t) = S_prev × e^(-λ × Δt)
  where λ = ln(2) / half_life_days
  """
  def calculate_current_score(score, last_updated, current_time, half_life_days) do
    if last_updated == nil do
      score
    else
      delta_time_days = (current_time - last_updated) / @milliseconds_per_day
      lambda = :math.log(2) / half_life_days
      decayed_score = score * :math.exp(-lambda * delta_time_days)

      # Ensure score doesn't go below 0
      max(0.0, decayed_score)
    end
  end

  @doc """
  Records a habit completion by applying decay and then adding a boost with diminishing returns.

  ## Parameters
  - `score`: Current momentum score (0-100)
  - `last_updated`: Unix timestamp in milliseconds when score was last updated
  - `current_time`: Current Unix timestamp in milliseconds
  - `half_life_days`: Number of days for score to decay by 50%
  - `boost_amount`: Base boost amount (default 60)

  ## Process
  1. Calculate decayed score from last update to now
  2. Apply boost with diminishing returns: boost × (1 - current_score/100)
  3. Cap at maximum score of 100

  Returns: {new_score, current_time}
  """
  def record_completion(score, last_updated, current_time, half_life_days, boost_amount \\ 60.0) do
    current_score = calculate_current_score(score, last_updated, current_time, half_life_days)

    boost = boost_amount * (1 - current_score / @max_score)
    new_score = min(@max_score, current_score + boost)

    {new_score, current_time}
  end

  @doc """
  Gets the default half-life days based on habit periodicity.

  ## Defaults
  - Daily habits: 1.0 days
  - 3x/week habits: 2.3 days  
  - Weekly habits: 5-7 days
  """
  def get_default_half_life(:day), do: 1.0
  def get_default_half_life(:week), do: 6.0
  def get_default_half_life(:month), do: 18.0

  @doc """
  Gets current Unix timestamp in milliseconds.
  """
  def current_timestamp do
    System.system_time(:millisecond)
  end
end
