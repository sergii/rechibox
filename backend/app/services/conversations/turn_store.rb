module Conversations
  class TurnStore
    def self.default
      Persistence.validate!
      return TurnStores::ActiveRecord.new if Persistence.active_record?

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
