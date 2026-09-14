module Conversations
  class Store
    def self.default
      Stores::JsonDirectory.new
    end

    def create(world_id:)
      raise NotImplementedError, "#{self.class.name} must implement #create(world_id:)"
    end

    def fetch(id)
      raise NotImplementedError, "#{self.class.name} must implement #fetch(id)"
    end

    def append(id:, messages:)
      raise NotImplementedError, "#{self.class.name} must implement #append(id:, messages:)"
    end
  end
end
