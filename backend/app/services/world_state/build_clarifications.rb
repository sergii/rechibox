module WorldState
  class BuildClarifications
    MAX_OPTIONS = 3

    def initialize(
      world_id:,
      resolution:,
      conversation_id: nil,
      message_id: nil,
      turn_id: nil,
      situation: nil,
      store: ClarificationStore.default
    )
      @world_id = world_id
      @resolution = resolution.to_h
      @conversation_id = conversation_id
      @message_id = message_id
      @turn_id = turn_id
      @situation = situation&.to_h
      @store = store
    end

    def call
      Array(@resolution["resolutions"]).filter_map do |row|
        next if row["status"] == "resolved"

        candidates = Array(row["candidates"]).first(MAX_OPTIONS)
        next if candidates.size < 2

        @store.create(
          world_id: @world_id,
          clarification: {
            "situation_entity_ref" => row.fetch("situation_entity_ref"),
            "mention" => {
              "kind" => row.fetch("kind"),
              "label" => row.fetch("label")
            },
            "question" => build_question(row.fetch("label"), candidates),
            "options" => candidates.each_with_index.map { |candidate, index| build_option(candidate, index) },
            "resume_context" => resume_context
          }.compact
        )
      end
    end

    private

    def resume_context
      return unless @conversation_id && @message_id && @situation

      {
        "conversation_id" => @conversation_id,
        "message_id" => @message_id,
        "turn_id" => @turn_id,
        "situation" => @situation,
        "entity_resolution" => @resolution
      }.compact
    end

    def build_question(label, candidates)
      labels = candidates.map { |candidate| candidate.fetch("label") }
      "Which '#{label}' do you mean: #{labels.join(' / ')}?"
    end

    def build_option(candidate, index)
      {
        "option_id" => (index + 1).to_s,
        "entity_id" => candidate.fetch("entity_id"),
        "label" => candidate.fetch("label"),
        "kind" => candidate.fetch("kind"),
        "score" => candidate.fetch("score")
      }
    end
  end
end
