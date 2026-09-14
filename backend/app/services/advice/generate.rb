require "securerandom"
require "time"

module Advice
  class Generate
    TRACE_VERSION = "0.3"

    def initialize(
      message:,
      history: [],
      world_state: nil,
      limit: nil,
      extractor: Ai::SituationExtractor.default,
      answer_generator: Ai::AnswerGenerator.default,
      trace_recorder: Ai::TraceRecorder.default,
      catalog: Knowledge::Catalog.default
    )
      @message = message
      @history = Array(history)
      @world_state = world_state
      @limit = limit
      @extractor = extractor
      @answer_generator = answer_generator
      @trace_recorder = trace_recorder
      @catalog = catalog
    end

    def call
      started_at = Time.now.utc
      started_monotonic = monotonic_now

      situation, extraction_latency_ms = measure do
        @extractor.call(message: @message, history: @history, world_state: @world_state)
      end

      retrieval, retrieval_latency_ms = measure do
        Knowledge::Retriever.new(
          catalog: @catalog,
          situation: situation,
          limit: @limit
        ).call
      end

      records = retrieval.fetch("candidates").map { |candidate| @catalog.fetch(candidate.fetch("id")) }
      context, context_latency_ms = measure do
        Ai::ContextComposer.new(
          situation: situation,
          knowledge: records,
          conversation: @history,
          world_state: @world_state
        ).call
      end

      answer, answer_latency_ms = measure do
        @answer_generator.call(context: context)
      end

      metrics = build_metrics(
        started_monotonic: started_monotonic,
        extraction_latency_ms: extraction_latency_ms,
        retrieval_latency_ms: retrieval_latency_ms,
        context_latency_ms: context_latency_ms,
        answer_latency_ms: answer_latency_ms
      )

      result = {
        "mode" => @extractor.mode,
        "answer_mode" => @answer_generator.mode,
        "trace_mode" => @trace_recorder.mode,
        "situation" => situation,
        "retrieval" => retrieval,
        "context" => context,
        "metrics" => metrics
      }
      result["answer"] = answer if answer

      trace = build_trace(
        started_at: started_at,
        situation: situation,
        retrieval: retrieval,
        metrics: metrics,
        answer: answer
      )
      trace_id = @trace_recorder.record(trace: trace)
      result["trace_id"] = trace_id if trace_id

      result
    end

    private

    def measure
      started = monotonic_now
      value = yield
      [value, elapsed_ms(started)]
    end

    def build_metrics(started_monotonic:, extraction_latency_ms:, retrieval_latency_ms:, context_latency_ms:, answer_latency_ms:)
      extraction_usage = normalized_usage(@extractor.usage)
      answer_usage = normalized_usage(@answer_generator.usage)

      {
        "timings_ms" => {
          "extraction" => extraction_latency_ms,
          "retrieval" => retrieval_latency_ms,
          "context_composition" => context_latency_ms,
          "answer_generation" => answer_latency_ms,
          "total" => elapsed_ms(started_monotonic)
        },
        "usage" => {
          "extraction" => extraction_usage,
          "answer_generation" => answer_usage,
          "total" => aggregate_usage(extraction_usage, answer_usage)
        }
      }
    end

    def aggregate_usage(*stages)
      input_tokens = sum_known(stages, "input_tokens")
      output_tokens = sum_known(stages, "output_tokens")
      costs = stages.map { |stage| stage["estimated_cost_usd"] }.compact

      {
        "input_tokens" => input_tokens,
        "output_tokens" => output_tokens,
        "estimated_cost_usd" => costs.empty? ? nil : costs.sum.round(8)
      }
    end

    def sum_known(stages, key)
      values = stages.map { |stage| stage[key] }.compact
      values.empty? ? nil : values.sum
    end

    def normalized_usage(value)
      usage = value.is_a?(Hash) ? value : {}

      {
        "input_tokens" => usage["input_tokens"],
        "output_tokens" => usage["output_tokens"],
        "estimated_cost_usd" => usage["estimated_cost_usd"]
      }
    end

    def build_trace(started_at:, situation:, retrieval:, metrics:, answer:)
      {
        "trace_version" => TRACE_VERSION,
        "id" => SecureRandom.uuid,
        "started_at" => started_at.iso8601(6),
        "latency_ms" => metrics.dig("timings_ms", "total"),
        "timings_ms" => metrics.fetch("timings_ms"),
        "raw_input" => @message.to_s,
        "conversation_history" => @history,
        "world_state" => @world_state,
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
          "prompt_version" => @extractor.mode == "ai_extracted" ? "situation-v0.1" : nil,
          "usage" => metrics.dig("usage", "extraction")
        },
        "answer_generator" => {
          "mode" => @answer_generator.mode,
          "model" => env_value("AI_ANSWER_MODEL"),
          "prompt_version" => @answer_generator.mode == "ruby_llm" ? "answer-v0.1" : nil,
          "usage" => metrics.dig("usage", "answer_generation")
        },
        "usage" => metrics.dig("usage", "total"),
        "answer" => answer
      }
    end

    def monotonic_now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def elapsed_ms(started)
      ((monotonic_now - started) * 1000).round(1)
    end

    def env_value(name)
      value = ENV[name].to_s.strip
      value.empty? ? nil : value
    end
  end
end
