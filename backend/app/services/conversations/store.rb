module Conversations
  class Store
    def self.default
      Stores::JsonDirectory.new
    end

    def create
      raise NotImplementedError, "#{self.class.name} must implement #create"
    end

    def fetch(id)
      raise NotImplementedError, "#{self.class.name} must implement #fetch(id)"
    end

    def append(id:, messages:)
      raise NotImplementedError, "#{self.class.name} must implement #append(id:, messages:)"
    end
  end
end
