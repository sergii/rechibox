module WorldState
  class NaturalQuery
    CONTRACT_VERSION = "0.1"

    def initialize(world_id:, interpreter: Ai::WorldQueryInterpreter.default, store: Store.default)
      @world_id = world_id
      @interpreter = interpreter
      @store = store
    end

    def call(message:, max_depth: nil)
      interpretation = @interpreter.call(message: message)
      return disabled_result(interpretation) if interpretation["query"].nil?

      world = @store.fetch(@world_id)
      query = interpretation.fetch("query")
      entity = query.fetch("entity")
      resolution = ResolveEntities.new(
        world: world,
        situation: { "entities" => [entity] }
      ).call.fetch("resolutions").first

      result = {
        "contract_version" => CONTRACT_VERSION,
        "world_id" => @world_id,
        "mode" => @interpreter.mode,
        "interpretation" => interpretation,
        "resolution" => resolution,
        "query_result" => nil,
        "usage" => @interpreter.usage.to_h
      }

      return result unless resolution.fetch("status") == "resolved"

      result["query_result"] = Query.new(world_id: @world_id).call(
        intent: query.fetch("intent"),
        entity_id: resolution.fetch("durable_entity_id"),
        max_depth: max_depth
      )
      result
    end

    private

    def disabled_result(interpretation)
      {
        "contract_version" => CONTRACT_VERSION,
        "world_id" => @world_id,
        "mode" => @interpreter.mode,
        "interpretation" => interpretation,
        "resolution" => nil,
        "query_result" => nil,
        "usage" => @interpreter.usage.to_h
      }
    end
  end
end
