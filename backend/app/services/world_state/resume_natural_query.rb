module WorldState
  class ResumeNaturalQuery
    CONTRACT_VERSION = "0.1"

    def initialize(
      world_id:,
      clarification_id:,
      action:,
      option_id: nil,
      clarification_store: ClarificationStore.default,
      world_store: Store.default,
      renderer: QueryAnswerRenderer.new
    )
      @world_id = world_id
      @clarification_id = clarification_id
      @action = action.to_s
      @option_id = option_id
      @clarification_store = clarification_store
      @world_store = world_store
      @renderer = renderer
    end

    def call
      pending = @clarification_store.fetch(world_id: @world_id, id: @clarification_id)
      context = pending.fetch("resume_context", {})
      raise ArgumentError, "clarification does not belong to a natural query" unless context["kind"] == "natural_query"

      clarification = AnswerClarification.new(
        world_id: @world_id,
        clarification_id: @clarification_id,
        action: @action,
        option_id: @option_id,
        store: @clarification_store,
        world_store: @world_store
      ).call

      message = context.fetch("message")
      query = context.fetch("query")
      resolution = resolution_for(clarification, query)
      query_result = nil

      if clarification.fetch("status") == "resolved"
        query_result = Query.new(world_id: @world_id).call(
          intent: query.fetch("intent"),
          entity_id: clarification.fetch("selected_entity_id"),
          max_depth: context["max_depth"]
        )
      end

      {
        "contract_version" => CONTRACT_VERSION,
        "world_id" => @world_id,
        "clarification" => clarification,
        "resolution" => resolution,
        "query_result" => query_result,
        "answer" => @renderer.call(
          message: message,
          query: query,
          resolution: resolution,
          query_result: query_result
        )
      }
    end

    private

    def resolution_for(clarification, query)
      if clarification.fetch("status") == "resolved"
        {
          "situation_entity_ref" => query.dig("entity", "ref") || "E1",
          "kind" => query.dig("entity", "kind") || "other",
          "label" => query.dig("entity", "label").to_s,
          "status" => "resolved",
          "durable_entity_id" => clarification.fetch("selected_entity_id")
        }
      else
        {
          "situation_entity_ref" => query.dig("entity", "ref") || "E1",
          "kind" => query.dig("entity", "kind") || "other",
          "label" => query.dig("entity", "label").to_s,
          "status" => "unresolved",
          "candidates" => []
        }
      end
    end
  end
end
