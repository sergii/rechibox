module Advice
  class DryRun
    def initialize(situation:, limit: nil, catalog: Knowledge::Catalog.default)
      @situation = situation
      @limit = limit
      @catalog = catalog
    end

    def call
      retrieval = Knowledge::Retriever.new(
        catalog: @catalog,
        situation: @situation,
        limit: @limit
      ).call

      records = retrieval.fetch("candidates").map { |candidate| @catalog.fetch(candidate.fetch("id")) }

      {
        "mode" => "dry_run",
        "situation" => @situation,
        "retrieval" => retrieval,
        "context" => Ai::ContextComposer.new(
          situation: @situation,
          knowledge: records
        ).call
      }
    end
  end
end
