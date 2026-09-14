require "securerandom"
require "time"

module Advice
  class Generate
    TRACE_VERSION = "0.1"

    def initialize(
      message:,
      limit: nil,
      extractor: Ai::SituationExtractor.default,
      answer_generator: Ai::AnswerGenerator.default,
      trace_recorder: Ai::TraceRecorder.default,
      catalog: Knowledge::Catalog.default
    )
      @message = message
      @limit = limit
      @extractor = extractor
      @answer_generator = answer_generator
      @trace_recorder = trace_recorder
      @catalog = catalog
    end

    def call
      started_at = Time.now.utc
      started_monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)

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

      result = {
        "mode" => @extractor.mode,
        "answer_mode" => @answer_generator.mode,
        "trace_mode" => @trace_recorder.mode,
        "situation" => situation,
        "retrieval" => retrieval,
        "context" => context
      }
      result["answer"] = answer if answer

      trace = build_trace(
        started_at: started_at,
        started_monotonic: started_monotonic,
        situation: situation,
        retrieval: retrieval,
        answer: answer
      )
      trace_id = @trace_recorder.record(trace: trace)
      result["trace_id"] = trace_id if trace_id

      result
    end

    private

    def build_trace(started_at:, started_monotonic:, situation:, retrieval:, answer:)
      elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_monotonic) * 1000).round(1)

      {
        "trace_version" => TRACE_VERSION,
        "id" => SecureRandom.uuid,
        "started_at" => started_at.iso8601(6),
        "latency_ms" => elapsed_ms,
        "raw_input" => @message.to_s,
        "situation" => situation,
        "retrieval_strategy" => retrieval.fetch("strategy"),
        "retrieved_knowledge" => retrieval.fetch("candidates").map do |candidate|
          {
            "id" => candidate.fetch("id"),
            "revision" => candidate.fetch("revision"),
            "score" => candidate.fetch("score")
          }
        end,
        "extractor" => {
          "mode" => @extractor.mode,
          "model" => env_value("AI_SITUATION_MODEL"),
          "prompt_version" => @extractor.mode == "ai_extracted" ? "situation-v0.1" : nil
        },
        "answer_generator" => {
          "mode" => @answer_generator.mode,
          "model" => env_value("AI_ANSWER_MODEL"),
          "prompt_version" => @answer_generator.mode == "ruby_llm" ? "answer-v0.1" : nil
        },
        "usage" => {
          "input_tokens" => nil,
          "output_tokens" => nil,
          "cost_usd" => nil
        },
        "answer" => answer
      }
    end

    def env_value(name)
      value = ENV[name].to_s.strip
      value.empty? ? nil : value
    end
  end
end
