module Advice
  class Generate
    def initialize(
      message:,
      limit: nil,
      extractor: Ai::SituationExtractor.default,
      answer_generator: Ai::AnswerGenerator.default,
      catalog: Knowledge::Catalog.default
    )
      @message = message
      @limit = limit
      @extractor = extractor
      @answer_generator = answer_generator
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
      context = Ai::ContextComposer.new(
        situation: situation,
        knowledge: records
      ).call
      answer = @answer_generator.call(context: context)

      {
        "mode" => @extractor.mode,
        "answer_mode" => @answer_generator.mode,
        "situation" => situation,
        "retrieval" => retrieval,
        "context" => context
      }.tap do |result|
        result["answer"] = answer if answer
      end
    end
  end
end
