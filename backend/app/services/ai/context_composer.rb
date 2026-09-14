module Ai
  class ContextComposer
    def initialize(situation:, knowledge:, conversation: [])
      @situation = situation
      @knowledge = knowledge
      @conversation = Array(conversation)
    end

    def call
      {
        "behavior" => [
          "Preserve uncertainty.",
          "Do not invent facts.",
          "Prefer concrete actions over generic advice."
        ],
        "conversation" => @conversation,
        "situation" => @situation,
        "knowledge" => @knowledge.map do |record|
          {
            "id" => record.fetch("id"),
            "revision" => record.fetch("revision"),
            "type" => record.fetch("type"),
            "summary" => record.fetch("summary"),
            "content" => record.fetch("content")
          }
        end
      }
    end
  end
end
