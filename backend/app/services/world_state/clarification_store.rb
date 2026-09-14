module WorldState
  class ClarificationStore
    def self.default
      ClarificationStores::JsonDirectory.new
    end

    def create(world_id:, clarification:)
      raise NotImplementedError, "#{self.class.name} must implement #create(world_id:, clarification:)"
    end

    def fetch(world_id:, id:)
      raise NotImplementedError, "#{self.class.name} must implement #fetch(world_id:, id:)"
    end

    def list(world_id:)
      raise NotImplementedError, "#{self.class.name} must implement #list(world_id:)"
    end

    def update(world_id:, id:)
      raise NotImplementedError, "#{self.class.name} must implement #update(world_id:, id:)"
    end
  end
end
