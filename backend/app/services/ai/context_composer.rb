module Ai
  class ContextComposer
    def initialize(situation:, knowledge:)
      @situation = situation
      @knowledge = knowledge
    end

    def call
      {
        "behavior" => [
          "Preserve uncertainty.",
          "Do not invent facts.",
          "Prefer concrete actions over generic advice."
        ],
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
