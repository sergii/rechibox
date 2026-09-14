require "time"

module WorldState
  class AnswerClarification
    ACTIONS = %w[select none_of_above].freeze

    def initialize(world_id:, clarification_id:, action:, option_id: nil, store: ClarificationStore.default, world_store: Store.default)
      @world_id = world_id
      @clarification_id = clarification_id
      @action = action.to_s
      @option_id = option_id.to_s
      @store = store
      @world_store = world_store
    end

    def call
      raise ArgumentError, "unsupported clarification action" unless ACTIONS.include?(@action)

      @store.update(world_id: @world_id, id: @clarification_id) do |record|
        raise ArgumentError, "clarification is already closed" unless record.fetch("status") == "pending"

        if @action == "select"
          resolve_selection!(record)
        else
          record["status"] = "none_of_above"
          record["resolved_at"] = Time.now.utc.iso8601(6)
        end
      end
    end

    private

    def resolve_selection!(record)
      raise ArgumentError, "option_id must not be blank" if @option_id.empty?

      option = Array(record["options"]).find { |candidate| candidate.fetch("option_id") == @option_id }
      raise ArgumentError, "clarification option not found" unless option

      world = @world_store.fetch(@world_id)
      entity = world.fetch("entities").find do |candidate|
        candidate.fetch("id") == option.fetch("entity_id") && candidate["status"] != "merged"
      end
      raise ArgumentError, "clarification option is stale" unless entity

      record["status"] = "resolved"
      record["selected_option_id"] = @option_id
      record["selected_entity_id"] = entity.fetch("id")
      record["resolved_at"] = Time.now.utc.iso8601(6)
    end
  end
end
