module Advice
  class Generate
    def initialize(
      message:,
      limit: nil,
      extractor: Ai::SituationExtractor.default,
      catalog: Knowledge::Catalog.default
    )
      @message = message
      @limit = limit
      @extractor = extractor
      @catalog = catalog
    end

    def call
      situation = @extractor.call(message: @message)
      retrieval = Knowledge::Retriever.new(
        catalog: @catalog,
        situation: situation,
        limit: @limit
      ).call
      records = retrieval.fetch("candidates").map { |candidate| @catalog.fetch(candidate.fetch("id")) }

      {
        "mode" => @extractor.mode,
        "situation" => situation,
        "retrieval" => retrieval,
        "context" => Ai::ContextComposer.new(
          situation: situation,
          knowledge: records
        ).call
      }
    end
  end
end
