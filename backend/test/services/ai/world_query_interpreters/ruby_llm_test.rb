require "test_helper"

class RubyLlmWorldQueryInterpreterTest < ActiveSupport::TestCase
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

  test "maps natural language to a bounded query intent and entity mention" do
    chat = FakeChat.new(
      "intent" => "where_is",
      "entity" => {
        "ref" => "bad-ref",
        "kind" => "item",
        "label" => "кабелі"
      }
    )
    interpreter = Ai::WorldQueryInterpreters::RubyLlm.new(chat: chat)

    result = interpreter.call(message: "Де мої кабелі?")

    assert_equal "ruby_llm", result.fetch("mode")
    assert_equal "where_is", result.dig("query", "intent")
    assert_equal "E1", result.dig("query", "entity", "ref")
    assert_equal "item", result.dig("query", "entity", "kind")
    assert_equal "кабелі", result.dig("query", "entity", "label")
    assert_equal Ai::WorldQueryInterpreters::RubyLlm::SCHEMA, chat.schema
    assert_includes chat.prompt, "Do not answer the question"
    assert_includes chat.prompt, "Де мої кабелі?"
  end

  test "rejects unsupported intent even if a fake response bypasses schema enforcement" do
    interpreter = Ai::WorldQueryInterpreters::RubyLlm.new(
      chat: FakeChat.new(
        "intent" => "delete_everything",
        "entity" => { "ref" => "E1", "kind" => "other", "label" => "everything" }
      )
    )

    assert_raises ArgumentError do
      interpreter.call(message: "Delete everything")
    end
  end
end
