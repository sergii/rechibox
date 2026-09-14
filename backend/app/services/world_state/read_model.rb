module WorldState
  class ReadModel
    ENTITY_FILTERS = %w[kind status label].freeze
    CLAIM_FILTERS = %w[predicate status source subject_id object_entity_id object_value].freeze

    def initialize(world_id:, store: Store.default)
      @world_id = world_id
      @store = store
    end

    def entities(filters = {})
      normalized = normalize(filters, ENTITY_FILTERS)
      return relational_entities(normalized) if Persistence.active_record?

      Array(@store.fetch(@world_id)["entities"]).select do |entity|
        normalized.all? { |key, value| entity[key].to_s == value }
      end
    end

    def claims(filters = {})
      normalized = normalize(filters, CLAIM_FILTERS)
      return relational_claims(normalized) if Persistence.active_record?

      Array(@store.fetch(@world_id)["claims"]).select do |claim|
        normalized.all? { |key, value| claim_matches?(claim, key, value) }
      end
    end

    private

    def relational_entities(filters)
      ensure_world_exists!
      relation = WorldEntity.where(world_id: @world_id).order(:position, :id)
      filters.each { |key, value| relation = relation.where(key => value) }
      relation.map { |entity| entity.payload.deep_dup }
    end

    def relational_claims(filters)
      ensure_world_exists!
      relation = WorldClaim.where(world_id: @world_id).order(:position, :id)
      relation = relation.where(predicate: filters["predicate"]) if filters["predicate"]
      relation = relation.where(status: filters["status"]) if filters["status"]
      relation = relation.where(source: filters["source"]) if filters["source"]
      relation = relation.where(subject_id: filters["subject_id"]) if filters["subject_id"]
      relation = relation.where("object ->> 'id' = ?", filters["object_entity_id"]) if filters["object_entity_id"]
      relation = relation.where("object ->> 'value' = ?", filters["object_value"]) if filters["object_value"]
      relation.map { |claim| claim.payload.deep_dup }
    end

    def ensure_world_exists!
      WorldDocument.find(@world_id)
    rescue ::ActiveRecord::RecordNotFound
      raise KeyError, "world state not found"
    end

    def claim_matches?(claim, key, value)
      case key
      when "object_entity_id"
        claim.dig("object", "id").to_s == value
      when "object_value"
        claim.dig("object", "value").to_s == value
      else
        claim[key].to_s == value
      end
    end

    def normalize(filters, allowed)
      filters.to_h.each_with_object({}) do |(key, value), result|
        key = key.to_s
        next unless allowed.include?(key)
        next if value.nil? || value.to_s.strip.empty?

        result[key] = value.to_s
      end
    end
  end
end
