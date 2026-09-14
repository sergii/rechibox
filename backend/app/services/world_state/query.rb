module WorldState
  class Query
    CONTRACT_VERSION = "0.1"
    INTENTS = %w[
      where_is
      what_is_in
      contents_recursive
      who_owns
      who_has_custody
    ].freeze

    def initialize(world_id:, read_model: ReadModel.new(world_id: world_id), graph: nil)
      @world_id = world_id
      @read_model = read_model
      @graph = graph || Graph.new(world_id: world_id, read_model: read_model)
    end

    def call(intent:, entity_id:, max_depth: nil)
      intent = intent.to_s
      raise ArgumentError, "unsupported world query intent" unless INTENTS.include?(intent)

      entity_id = entity_id.to_s
      ensure_entity!(entity_id)

      result = case intent
      when "where_is"
        where_is(entity_id, max_depth)
      when "what_is_in"
        what_is_in(entity_id)
      when "contents_recursive"
        contents_recursive(entity_id, max_depth)
      when "who_owns"
        relation_targets(entity_id, "ownership")
      when "who_has_custody"
        relation_targets(entity_id, "custody")
      end

      {
        "contract_version" => CONTRACT_VERSION,
        "world_id" => @world_id,
        "intent" => intent,
        "entity_id" => entity_id,
        "result" => result
      }
    end

    private

    def where_is(entity_id, max_depth)
      location = @graph.physical_location(
        entity_id: entity_id,
        max_depth: max_depth || Graph::DEFAULT_MAX_DEPTH
      )

      {
        "ambiguous" => location.fetch("ambiguous"),
        "paths" => location.fetch("paths")
      }
    end

    def what_is_in(entity_id)
      tree = @graph.physical_tree(root_id: entity_id, max_depth: 1)
      child_ids = tree.fetch("edges").filter_map do |edge|
        edge.fetch("to_entity_id") if edge.fetch("from_entity_id") == entity_id
      end.uniq
      entities = entity_index

      {
        "entity_ids" => child_ids,
        "entities" => child_ids.filter_map { |id| entities[id] },
        "edges" => tree.fetch("edges")
      }
    end

    def contents_recursive(entity_id, max_depth)
      @graph.physical_tree(
        root_id: entity_id,
        max_depth: max_depth || Graph::DEFAULT_MAX_DEPTH
      )
    end

    def relation_targets(entity_id, predicate)
      relations = @graph.relations(predicates: [predicate]).select do |edge|
        edge.fetch("from_entity_id") == entity_id
      end
      targets = relations.map { |edge| edge.fetch("to_entity_id") }.uniq
      entities = entity_index
      targets.select! { |id| entities.key?(id) }

      {
        "ambiguous" => targets.size > 1,
        "entity_ids" => targets,
        "entities" => targets.filter_map { |id| entities[id] },
        "edges" => relations.select { |edge| targets.include?(edge.fetch("to_entity_id")) }
      }
    end

    def entity_index
      @entity_index ||= @read_model.entities.each_with_object({}) do |entity, result|
        next if entity["status"] == "merged"

        result[entity.fetch("id").to_s] = entity
      end
    end

    def ensure_entity!(entity_id)
      raise KeyError, "world entity not found" unless entity_index.key?(entity_id)
    end
  end
end
