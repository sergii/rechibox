module Conversations
  class TurnStore
    def self.default
      TurnStores::JsonDirectory.new
    end

    def create(conversation_id:, message_id:)
      raise NotImplementedError
    end

    def fetch(conversation_id:, id:)
      raise NotImplementedError
    end

    def list(conversation_id:)
      raise NotImplementedError
    end

    def update(conversation_id:, id:)
      raise NotImplementedError
    end
  end
end
