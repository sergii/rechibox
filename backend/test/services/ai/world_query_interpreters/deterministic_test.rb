require "test_helper"

class AiWorldQueryInterpretersDeterministicTest < ActiveSupport::TestCase
  test "parses Ukrainian location question without a model" do
    result = interpreter.call(message: "Де мої кабелі?")

    assert_equal "deterministic", result.fetch("mode")
    assert_equal "where_is", result.dig("query", "intent")
    assert_equal "кабелі", result.dig("query", "entity", "label")
    assert_equal "other", result.dig("query", "entity", "kind")
  end

  test "parses direct contents question" do
    result = interpreter.call(message: "Що в синій коробці?")

    assert_equal "what_is_in", result.dig("query", "intent")
    assert_equal "синій коробці", result.dig("query", "entity", "label")
  end

  test "parses custody separately from ownership" do
    custody = interpreter.call(message: "Хто зберігає дриль?")
    ownership = interpreter.call(message: "Кому належить дриль?")

    assert_equal "who_has_custody", custody.dig("query", "intent")
    assert_equal "who_owns", ownership.dig("query", "intent")
  end

  test "unsupported wording fails closed without inventing a query" do
    result = interpreter.call(message: "Допоможи мені прибрати гараж")

    assert_nil result["query"]
    assert_equal "unsupported", result["reason"]
  end

  private

  def interpreter
    Ai::WorldQueryInterpreters::Deterministic.new
  end
end
