module WorldState
  class NaturalQuery
    CONTRACT_VERSION = "0.1"
    MAX_CLARIFICATION_OPTIONS = 3

    def initialize(
      world_id:,
      interpreter: Ai::WorldQueryInterpreter.default,
      store: Store.default,
      renderer: QueryAnswerRenderer.new,
      clarification_store: ClarificationStore.default
    )
      @world_id = world_id
      @interpreter = interpreter
      @store = store
      @renderer = renderer
      @clarification_store = clarification_store
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
        "clarification" => nil,
        "query_result" => nil,
        "answer" => nil,
        "usage" => @interpreter.usage.to_h
      }

      if resolution.fetch("status") == "resolved"
        result["query_result"] = execute_query(query: query, entity_id: resolution.fetch("durable_entity_id"), max_depth: max_depth)
      elsif resolution.fetch("status") == "ambiguous"
        result["clarification"] = create_clarification(
          message: message,
          query: query,
          resolution: resolution,
          max_depth: max_depth
        )
      end

      result["answer"] = @renderer.call(
        message: message,
        query: query,
        resolution: resolution,
        query_result: result["query_result"]
      )
      result
    end

    private

    def execute_query(query:, entity_id:, max_depth:)
      Query.new(world_id: @world_id).call(
        intent: query.fetch("intent"),
        entity_id: entity_id,
        max_depth: max_depth
      )
    end

    def create_clarification(message:, query:, resolution:, max_depth:)
      candidates = Array(resolution["candidates"]).first(MAX_CLARIFICATION_OPTIONS)
      return if candidates.size < 2

      @clarification_store.create(
        world_id: @world_id,
        clarification: {
          "situation_entity_ref" => query.dig("entity", "ref") || "E1",
          "mention" => {
            "kind" => query.dig("entity", "kind") || "other",
            "label" => query.dig("entity", "label").to_s
          },
          "question" => clarification_question(query.dig("entity", "label").to_s, message),
          "options" => candidates.each_with_index.map do |candidate, index|
            {
              "option_id" => (index + 1).to_s,
              "entity_id" => candidate.fetch("entity_id"),
              "label" => candidate.fetch("label"),
              "kind" => candidate.fetch("kind"),
              "score" => candidate.fetch("score")
            }
          end,
          "resume_context" => {
            "kind" => "natural_query",
            "message" => message.to_s,
            "query" => query,
            "max_depth" => max_depth
          }.compact
        }
      )
    end

    def clarification_question(label, message)
      if message.to_s.match?(/[А-Яа-яІіЇїЄєҐґ]/)
        "Який саме об'єкт «#{label}» ви маєте на увазі?"
      else
        "Which “#{label}” do you mean?"
      end
    end

    def disabled_result(interpretation)
      {
        "contract_version" => CONTRACT_VERSION,
        "world_id" => @world_id,
        "mode" => @interpreter.mode,
        "interpretation" => interpretation,
        "resolution" => nil,
        "clarification" => nil,
        "query_result" => nil,
        "answer" => nil,
        "usage" => @interpreter.usage.to_h
      }
    end
  end
end
