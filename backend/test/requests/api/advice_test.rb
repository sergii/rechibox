require "test_helper"
require "json"
require "tmpdir"

class ApiAdviceTest < ActionDispatch::IntegrationTest
  setup do
    ENV["ORGANIZED_RUNTIME_PATH"] = Rails.root.join("test/fixtures/organized-v1.jsonl").to_s
  end

  test "raw message flows through extractor retrieval and context composition without a model call" do
    message = "Третій день перекладаю коробки з підлоги на диван. У списку ще є речі, які вже продав."

    post "/api/advice", params: { message:, limit: 2 }, as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal "model_free", body.fetch("mode")
    assert_equal "disabled", body.fetch("answer_mode")
    assert_equal "disabled", body.fetch("trace_mode")
    assert_not body.key?("answer")
    assert_not body.key?("trace_id")
    assert_equal "0.1", body.dig("situation", "contract_version")
    assert_equal message, body.dig("situation", "raw_input")
    assert_empty body.dig("situation", "facts")
    assert_equal "lexical-idf-prefix5-v0.1", body.dig("retrieval", "strategy")
    assert_includes body.dig("retrieval", "candidates").map { |candidate| candidate.fetch("id") }, "ORG-PR-0001"
    assert_equal body.dig("retrieval", "candidates").map { |candidate| candidate.fetch("id") },
                 body.dig("context", "knowledge").map { |record| record.fetch("id") }
    assert body.dig("metrics", "timings_ms", "total") >= 0
    assert body.dig("metrics", "timings_ms", "retrieval") >= 0
    assert_nil body.dig("metrics", "usage", "total", "input_tokens")
    assert_nil body.dig("metrics", "usage", "total", "estimated_cost_usd")
  end

  test "raw advice can persist a reproducible JSONL trace" do
    Dir.mktmpdir do |dir|
      previous_store = ENV["AI_TRACE_STORE"]
      previous_path = ENV["AI_TRACE_PATH"]
      ENV["AI_TRACE_STORE"] = "jsonl"
      ENV["AI_TRACE_PATH"] = File.join(dir, "ai-runs.jsonl")

      post "/api/advice", params: {
        message: "Третій день перекладаю коробки з підлоги на диван.",
        limit: 2
      }, as: :json

      assert_response :success
      body = response.parsed_body
      assert_equal "jsonl", body.fetch("trace_mode")
      assert body.fetch("trace_id").present?

      trace = JSON.parse(File.read(ENV.fetch("AI_TRACE_PATH")))
      assert_equal body.fetch("trace_id"), trace.fetch("id")
      assert_equal "0.2", trace.fetch("trace_version")
      assert_equal "lexical-idf-prefix5-v0.1", trace.fetch("retrieval_strategy")
      assert_equal body.dig("retrieval", "candidates").map { |candidate| candidate.fetch("id") },
                   trace.fetch("retrieved_knowledge").map { |record| record.fetch("id") }
      assert_equal body.dig("metrics", "timings_ms"), trace.fetch("timings_ms")
      assert_nil trace.dig("usage", "input_tokens")
      assert_nil trace.dig("usage", "estimated_cost_usd")
    ensure
      ENV["AI_TRACE_STORE"] = previous_store
      ENV["AI_TRACE_PATH"] = previous_path
    end
  end

  test "raw message rejects blank input" do
    post "/api/advice", params: { message: "   " }, as: :json

    assert_response :unprocessable_entity
  end

  test "dry run ranks Organized knowledge and composes context without a model call" do
    situation = {
      contract_version: "0.1",
      raw_input: "Третій день перекладаю коробки з підлоги на диван. У списку ще є речі, які вже продав.",
      facts: [
        { text: "Коробки багаторазово переміщуються між підлогою та диваном.", source: "user" },
        { text: "Продані речі залишаються в поточному списку.", source: "user" }
      ],
      goals: [{ text: "Бачити реальний прогрес.", source: "user" }],
      constraints: [],
      uncertainties: [],
      hypotheses: [],
      entities: []
    }

    post "/api/advice/dry_run", params: { situation:, limit: 2 }, as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal "dry_run", body.fetch("mode")
    assert_equal "lexical-idf-prefix5-v0.1", body.dig("retrieval", "strategy")
    assert_equal 2, body.dig("retrieval", "returned_count")
    assert_includes body.dig("retrieval", "candidates").map { |candidate| candidate.fetch("id") }, "ORG-PR-0001"
    assert_equal body.dig("retrieval", "candidates").map { |candidate| candidate.fetch("id") },
                 body.dig("context", "knowledge").map { |record| record.fetch("id") }
  end

  test "dry run rejects the wrong situation contract" do
    post "/api/advice/dry_run", params: { situation: { contract_version: "9" } }, as: :json

    assert_response :unprocessable_entity
  end
end
