module WorldState
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

    def update(id:)
      raise NotImplementedError, "#{self.class.name} must implement #update(id:)"
    end
  end
end
