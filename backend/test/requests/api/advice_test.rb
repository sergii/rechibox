require "test_helper"

class ApiAdviceTest < ActionDispatch::IntegrationTest
  setup do
    ENV["ORGANIZED_RUNTIME_PATH"] = Rails.root.join("test/fixtures/organized-v1.jsonl").to_s
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
