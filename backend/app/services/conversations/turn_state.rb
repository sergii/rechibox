require "time"

module Conversations
  class TurnState
    STATES = %w[
      processing
      awaiting_clarification
      ready_for_review
      completed
      failed
    ].freeze

    TRANSITIONS = {
      "processing" => %w[awaiting_clarification ready_for_review completed failed].freeze,
      "awaiting_clarification" => %w[ready_for_review completed].freeze,
      "ready_for_review" => %w[completed].freeze,
      "completed" => [].freeze,
      "failed" => [].freeze
    }.freeze

    def self.transition!(turn, to:, at: Time.now.utc)
      from = turn.fetch("status")
      target = to.to_s

      raise ArgumentError, "unknown conversation turn status: #{from}" unless STATES.include?(from)
      raise ArgumentError, "unknown conversation turn status: #{target}" unless STATES.include?(target)
      return turn if from == target

      unless TRANSITIONS.fetch(from).include?(target)
        raise ArgumentError, "illegal conversation turn transition: #{from} -> #{target}"
      end

      turn["status"] = target
      turn["completed_at"] ||= at.iso8601(6) if target == "completed"
      turn["failed_at"] ||= at.iso8601(6) if target == "failed"
      turn
    end
  end
end
