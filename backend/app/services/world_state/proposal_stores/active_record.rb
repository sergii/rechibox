require "securerandom"
require "time"

module WorldState
  module ProposalStores
    class ActiveRecord < ProposalStore
      CONTRACT_VERSION = "0.1"

      def create(world_id:, proposal:, proposer_mode:, context: nil)
        now = Time.now.utc.iso8601(6)
        lifecycle = normalized_context(context)
        record = {
          "contract_version" => CONTRACT_VERSION,
          "id" => SecureRandom.uuid,
          "world_id" => world_id,
          "status" => "pending",
          "created_at" => now,
          "updated_at" => now,
          "proposer_mode" => proposer_mode,
          "update" => proposal.fetch("update"),
          "reason" => proposal["reason"],
          "validation" => proposal.fetch("validation"),
          "conversation_id" => lifecycle["conversation_id"],
          "message_id" => lifecycle["message_id"],
          "turn_id" => lifecycle["turn_id"]
        }.compact
        StateUpdateProposalDocument.create!(id: record.fetch("id"), world_id: world_id, payload: record)
        record
      end

      def fetch(world_id:, id:)
        scoped(world_id).find(id).payload.deep_dup
      rescue ::ActiveRecord::RecordNotFound
        raise KeyError, "proposal not found"
      end

      def list(world_id:)
        scoped(world_id).order(:created_at, :id).map { |row| row.payload.deep_dup }
      end

      def update(world_id:, id:)
        row = scoped(world_id).find(id)
        proposal = nil
        row.with_lock do
          proposal = row.reload.payload.deep_dup
          yield proposal
          proposal["updated_at"] = Time.now.utc.iso8601(6)
          row.update!(payload: proposal)
        end
        proposal
      rescue ::ActiveRecord::RecordNotFound
        raise KeyError, "proposal not found"
      end

      private

      def scoped(world_id)
        StateUpdateProposalDocument.where(world_id: world_id)
      end

      def normalized_context(context)
        return {} unless context

        context.to_h.transform_keys(&:to_s).slice("conversation_id", "message_id", "turn_id")
      end
    end
  end
end
