module WorldState
  class Graph
    PHYSICAL_PREDICATES = %w[contains location].freeze
    RELATION_PREDICATES = %w[contains location ownership custody].freeze
    DEFAULT_MAX_DEPTH = 8
    MAX_DEPTH = 32

    def initialize(world_id:, read_model: ReadModel.new(world_id: world_id))
      @world_id = world_id
      @read_model = read_model
    end

    def physical_tree(root_id:, max_depth: DEFAULT_MAX_DEPTH)
      depth_limit = normalize_depth(max_depth)
      entities = indexed_entities
      ensure_entity!(entities, root_id)
      edges = physical_edges

      visited = { root_id.to_s => 0 }
      queue = [[root_id.to_s, 0]]
      selected_edges = []
      cycles = []

      until queue.empty?
        current_id, depth = queue.shift
        next if depth >= depth_limit

        edges.fetch(current_id, []).each do |edge|
          child_id = edge.fetch("to_entity_id")
          selected_edges << edge

          if visited.key?(child_id)
            cycles << edge if visited.fetch(child_id) <= depth
            next
          end

          visited[child_id] = depth + 1
          queue << [child_id, depth + 1]
        end
      end

      {
        "contract_version" => "0.1",
        "world_id" => @world_id,
        "root_entity_id" => root_id.to_s,
        "max_depth" => depth_limit,
        "nodes" => visited.keys.filter_map { |id| entities[id] },
        "edges" => selected_edges.uniq { |edge| edge.fetch("claim_id") },
        "cycles" => cycles.uniq { |edge| edge.fetch("claim_id") }
      }
    end

    def physical_location(entity_id:, max_depth: DEFAULT_MAX_DEPTH)
      depth_limit = normalize_depth(max_depth)
      entities = indexed_entities
      start_id = entity_id.to_s
      ensure_entity!(entities, start_id)
      parents = physical_parent_edges

      paths = []
      walk_location_paths(
        current_id: start_id,
        parents: parents,
        entities: entities,
        path_ids: [start_id],
        path_edges: [],
        depth_limit: depth_limit,
        paths: paths
      )

      {
        "contract_version" => "0.1",
        "world_id" => @world_id,
        "entity_id" => start_id,
        "max_depth" => depth_limit,
        "ambiguous" => paths.size > 1,
        "paths" => paths
      }
    end

    def relations(predicates: RELATION_PREDICATES)
      requested = Array(predicates).map(&:to_s) & RELATION_PREDICATES
      claims = @read_model.claims("status" => "active")

      claims.filter_map do |claim|
        next unless requested.include?(claim["predicate"].to_s)

        object_id = entity_object_id(claim)
        next unless claim["subject_id"] && object_id

        relation_edge(claim, from: claim.fetch("subject_id"), to: object_id)
      end
    end

    private

    def indexed_entities
      @indexed_entities ||= @read_model.entities.each_with_object({}) do |entity, result|
        next if entity["status"] == "merged"

        result[entity.fetch("id").to_s] = entity
      end
    end

    def physical_edges
      @physical_edges ||= begin
        result = Hash.new { |hash, key| hash[key] = [] }

        @read_model.claims("status" => "active").each do |claim|
          object_id = entity_object_id(claim)
          next unless object_id

          case claim["predicate"]
          when "contains"
            edge = physical_edge(claim, parent: claim["subject_id"], child: object_id)
          when "location"
            edge = physical_edge(claim, parent: object_id, child: claim["subject_id"])
          end
          next unless edge

          result[edge.fetch("from_entity_id")] << edge
        end

        result
      end
    end

    def physical_parent_edges
      result = Hash.new { |hash, key| hash[key] = [] }
      physical_edges.each_value do |edges|
        edges.each { |edge| result[edge.fetch("to_entity_id")] << edge }
      end
      result
    end

    def physical_edge(claim, parent:, child:)
      return unless parent && child
      return unless indexed_entities.key?(parent.to_s) && indexed_entities.key?(child.to_s)

      {
        "claim_id" => claim.fetch("id"),
        "predicate" => claim.fetch("predicate"),
        "from_entity_id" => parent.to_s,
        "to_entity_id" => child.to_s,
        "source" => claim["source"],
        "confidence" => claim["confidence"]
      }
    end

    def relation_edge(claim, from:, to:)
      {
        "claim_id" => claim.fetch("id"),
        "predicate" => claim.fetch("predicate"),
        "from_entity_id" => from.to_s,
        "to_entity_id" => to.to_s,
        "source" => claim["source"],
        "confidence" => claim["confidence"]
      }
    end

    def entity_object_id(claim)
      object = claim["object"]
      return unless object.is_a?(Hash) && object["type"] == "entity"

      object["id"]&.to_s
    end

    def walk_location_paths(current_id:, parents:, entities:, path_ids:, path_edges:, depth_limit:, paths:)
      candidate_edges = parents.fetch(current_id, [])
      if candidate_edges.empty? || path_edges.size >= depth_limit
        paths << build_path(path_ids, path_edges, entities, truncated: !candidate_edges.empty?)
        return
      end

      candidate_edges.each do |edge|
        parent_id = edge.fetch("from_entity_id")
        if path_ids.include?(parent_id)
          paths << build_path(path_ids + [parent_id], path_edges + [edge], entities, cycle: true)
          next
        end

        walk_location_paths(
          current_id: parent_id,
          parents: parents,
          entities: entities,
          path_ids: path_ids + [parent_id],
          path_edges: path_edges + [edge],
          depth_limit: depth_limit,
          paths: paths
        )
      end
    end

    def build_path(ids, edges, entities, cycle: false, truncated: false)
      {
        "entity_ids" => ids,
        "entities" => ids.filter_map { |id| entities[id] },
        "edges" => edges,
        "cycle" => cycle,
        "truncated" => truncated
      }
    end

    def ensure_entity!(entities, id)
      raise KeyError, "world entity not found" unless entities.key?(id.to_s)
    end

    def normalize_depth(value)
      depth = Integer(value || DEFAULT_MAX_DEPTH)
      raise ArgumentError, "max_depth must be between 1 and #{MAX_DEPTH}" unless depth.between?(1, MAX_DEPTH)

      depth
    rescue TypeError, ArgumentError => e
      raise e if e.message.start_with?("max_depth")

      raise ArgumentError, "max_depth must be an integer"
    end
  end
end
