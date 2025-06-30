defmodule Mmentum.Habits.MomentumTest do
  use ExUnit.Case, async: true
  alias Mmentum.Habits.Momentum

  describe "calculate_current_score/4" do
    test "returns original score when no time has passed" do
      score = 50.0
      current_time = 1000
      last_updated = 1000
      half_life = 1.0

      result = Momentum.calculate_current_score(score, last_updated, current_time, half_life)
      assert result == 50.0
    end

    test "applies exponential decay after one half-life" do
      score = 60.0
      # 1 day later
      current_time = 1000 + 86_400_000
      last_updated = 1000
      # 1 day half-life
      half_life = 1.0

      result = Momentum.calculate_current_score(score, last_updated, current_time, half_life)
      # After 1 half-life, score should be approximately 30.0
      assert_in_delta result, 30.0, 0.1
    end

    test "handles nil last_updated" do
      score = 50.0
      current_time = 1000
      last_updated = nil
      half_life = 1.0

      result = Momentum.calculate_current_score(score, last_updated, current_time, half_life)
      assert result == 50.0
    end
  end

  describe "record_completion/5" do
    test "cold start scenario" do
      score = 0.0
      current_time = 1000
      last_updated = nil
      half_life = 1.0
      boost_amount = 60.0

      {new_score, new_timestamp} =
        Momentum.record_completion(score, last_updated, current_time, half_life, boost_amount)

      # Should get full boost: 0 + 60*(1-0/100) = 60
      assert new_score == 60.0
      assert new_timestamp == current_time
    end

    test "hot streak scenario with diminishing returns" do
      score = 90.0
      current_time = 1000
      last_updated = 1000
      half_life = 1.0
      boost_amount = 60.0

      {new_score, new_timestamp} =
        Momentum.record_completion(score, last_updated, current_time, half_life, boost_amount)

      # Should get reduced boost: 90 + 60*(1-90/100) = 90 + 6 = 96
      assert new_score == 96.0
      assert new_timestamp == current_time
    end

    test "applies decay before boost" do
      score = 96.0
      # 1 day later
      current_time = 1000 + 86_400_000
      last_updated = 1000
      half_life = 1.0
      boost_amount = 60.0

      {new_score, new_timestamp} =
        Momentum.record_completion(score, last_updated, current_time, half_life, boost_amount)

      # First decay: 96 * e^(-ln(2)) ≈ 48
      # Then boost: 48 + 60*(1-48/100) = 48 + 31.2 = 79.2
      assert_in_delta new_score, 79.2, 1.0
      assert new_timestamp == current_time
    end
  end

  describe "get_momentum_tier/1" do
    test "returns correct tiers" do
      assert Momentum.get_momentum_tier(95.0) == "On Fire 🔥"
      assert Momentum.get_momentum_tier(80.0) == "On Fire 🔥"
      assert Momentum.get_momentum_tier(65.0) == "Rolling"
      assert Momentum.get_momentum_tier(50.0) == "Rolling"
      assert Momentum.get_momentum_tier(35.0) == "Warming Up"
      assert Momentum.get_momentum_tier(20.0) == "Warming Up"
      assert Momentum.get_momentum_tier(10.0) == "Cooling Off"
      assert Momentum.get_momentum_tier(0.0) == "Cooling Off"
    end
  end

  describe "get_default_half_life/1" do
    test "returns correct defaults for each periodicity" do
      assert Momentum.get_default_half_life(:day) == 1.0
      assert Momentum.get_default_half_life(:week) == 6.0
      assert Momentum.get_default_half_life(:month) == 18.0
    end
  end
end
