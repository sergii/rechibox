require "test_helper"

class ConversationsTurnStateTest < ActiveSupport::TestCase
  test "allows the declared lifecycle transitions" do
    legal = {
      "processing" => %w[awaiting_clarification ready_for_review completed failed],
      "awaiting_clarification" => %w[ready_for_review completed],
      "ready_for_review" => %w[completed]
    }

    legal.each do |from, targets|
      targets.each do |target|
        turn = { "status" => from }

        Conversations::TurnState.transition!(turn, to: target, at: Time.utc(2026, 9, 15, 12, 0, 0))

        assert_equal target, turn.fetch("status")
      end
    end
  end

  test "rejects transitions not declared by the lifecycle" do
    illegal = [
      ["awaiting_clarification", "processing"],
      ["ready_for_review", "awaiting_clarification"],
      ["completed", "ready_for_review"],
      ["completed", "failed"],
      ["failed", "processing"]
    ]

    illegal.each do |from, target|
      error = assert_raises(ArgumentError) do
        Conversations::TurnState.transition!({ "status" => from }, to: target)
      end

      assert_includes error.message, "illegal conversation turn transition"
    end
  end

  test "same-state application is idempotent" do
    turn = { "status" => "ready_for_review" }

    result = Conversations::TurnState.transition!(turn, to: "ready_for_review")

    assert_same turn, result
    assert_equal "ready_for_review", turn.fetch("status")
  end

  test "records terminal timestamps centrally" do
    completed = { "status" => "processing" }
    failed = { "status" => "processing" }
    at = Time.utc(2026, 9, 15, 12, 34, 56)

    Conversations::TurnState.transition!(completed, to: "completed", at: at)
    Conversations::TurnState.transition!(failed, to: "failed", at: at)

    assert_equal "2026-09-15T12:34:56.000000Z", completed.fetch("completed_at")
    assert_equal "2026-09-15T12:34:56.000000Z", failed.fetch("failed_at")
  end

  test "rejects unknown current and target statuses" do
    assert_raises(ArgumentError) do
      Conversations::TurnState.transition!({ "status" => "mystery" }, to: "completed")
    end

    assert_raises(ArgumentError) do
      Conversations::TurnState.transition!({ "status" => "processing" }, to: "mystery")
    end
  end
end
