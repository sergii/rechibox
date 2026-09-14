require "test_helper"

class RubyLlmSituationExtractorTest < ActiveSupport::TestCase
  FakeResponse = Struct.new(:content)

  class FakeChat
    attr_reader :schema, :prompt

    def initialize(content)
      @content = content
    end

    def with_schema(schema)
      @schema = schema
      self
    end

    def ask(prompt)
      @prompt = prompt
      FakeResponse.new(@content)
    end
  end

  test "extracts and normalizes a Situation Model without changing raw input" do
    content = {
      "facts" => [
        { "text" => "Кімната має приблизно 16 м².", "source" => "user", "confidence" => nil }
      ],
      "goals" => [
        { "text" => "Звільнити кімнату.", "source" => "user", "confidence" => nil }
      ],
      "constraints" => [],
      "uncertainties" => [
        { "text" => "Невідомо, що в коробках.", "source" => "inferred", "confidence" => 0.9 }
      ],
      "hypotheses" => [
        { "text" => "Робочого простору мало.", "source" => "inferred", "confidence" => 0.8 }
      ],
      "entities" => [
        {
          "ref" => "room",
          "kind" => "space",
          "label" => "кімната",
          "attributes" => [{ "name" => "area_m2", "value" => 16 }]
        }
      ]
    }
    chat = FakeChat.new(content)
    extractor = Ai::SituationExtractors::RubyLlm.new(chat: chat)
    message = "А що робити з коробками?"
    history = [{ "role" => "user", "text" => "У мене кімната 16 метрів." }]

    situation = extractor.call(message: message, history: history)

    assert_equal "ai_extracted", extractor.mode
    assert_equal "0.1", situation.fetch("contract_version")
    assert_equal message, situation.fetch("raw_input")
    assert_equal "Кімната має приблизно 16 м².", situation.dig("facts", 0, "text")
    refute situation.dig("facts", 0).key?("confidence")
    assert_equal 0.8, situation.dig("hypotheses", 0, "confidence")
    assert_equal "E1", situation.dig("entities", 0, "ref")
    assert_equal 16, situation.dig("entities", 0, "attributes", "area_m2")
    assert_equal Ai::SituationExtractors::RubyLlm::SCHEMA, chat.schema
    assert_includes chat.prompt, "Prior conversation"
    assert_includes chat.prompt, "У мене кімната 16 метрів."
    assert_includes chat.prompt, message
  end

  test "requires an explicit model when constructing a real RubyLLM chat" do
    error = assert_raises(ArgumentError) do
      Ai::SituationExtractors::RubyLlm.new(model: "")
    end

    assert_includes error.message, "AI_SITUATION_MODEL"
  end
end
