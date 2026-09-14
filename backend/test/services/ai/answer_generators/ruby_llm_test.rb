require "test_helper"

class RubyLlmAnswerGeneratorTest < ActiveSupport::TestCase
  FakeResponse = Struct.new(:content)

  class FakeChat
    attr_reader :instructions, :prompt

    def initialize(content)
      @content = content
    end

    def with_instructions(instructions)
      @instructions = instructions
      self
    end

    def ask(prompt)
      @prompt = prompt
      FakeResponse.new(@content)
    end
  end

  test "generates a final answer from composed context without exposing implementation details in the interface" do
    chat = FakeChat.new("Почніть з однієї коробки і змініть її стан, а не лише місце.")
    generator = Ai::AnswerGenerators::RubyLlm.new(chat: chat)
    context = {
      "behavior" => ["Preserve uncertainty."],
      "situation" => {
        "contract_version" => "0.1",
        "raw_input" => "Третій день перекладаю коробки.",
        "facts" => [],
        "goals" => [],
        "constraints" => [],
        "uncertainties" => [],
        "hypotheses" => [],
        "entities" => []
      },
      "knowledge" => [
        {
          "id" => "ORG-PR-0001",
          "revision" => 1,
          "type" => "principle",
          "summary" => "Touch things to change their state, not merely location.",
          "content" => {}
        }
      ]
    }

    answer = generator.call(context: context)

    assert_equal "Почніть з однієї коробки і змініть її стан, а не лише місце.", answer
    assert_equal "ruby_llm", generator.mode
    assert_includes chat.instructions, "do not expose internal knowledge IDs"
    assert_includes chat.prompt, "Третій день перекладаю коробки."
    assert_includes chat.prompt, "ORG-PR-0001"
  end

  test "rejects a blank model response" do
    generator = Ai::AnswerGenerators::RubyLlm.new(chat: FakeChat.new("   "))

    assert_raises(KeyError) { generator.call(context: {}) }
  end
end
