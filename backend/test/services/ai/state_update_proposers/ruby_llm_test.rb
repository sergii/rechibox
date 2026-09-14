require "test_helper"

class RubyLlmStateUpdateProposerTest < ActiveSupport::TestCase
  FakeResponse = Struct.new(:content)

  class FakeChat
    attr_reader :instructions, :schema, :prompt

    def initialize(content)
      @content = content
    end

    def with_instructions(instructions)
      @instructions = instructions
      self
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

  test "normalizes and validates a proposed state transition without mutating the world" do
    box_id = SecureRandom.uuid
    garage_id = SecureRandom.uuid
    shelf_id = SecureRandom.uuid
    claim_id = SecureRandom.uuid
    world = world_fixture(box_id: box_id, garage_id: garage_id, shelf_id: shelf_id, claim_id: claim_id)
    original = Marshal.load(Marshal.dump(world))

    content = {
      "proposals" => [
        {
          "operation" => "supersede",
          "predicate" => "location",
          "subject_id" => box_id,
          "target_claim_id" => claim_id,
          "key" => nil,
          "object" => { "type" => "entity", "entity_id" => shelf_id, "value" => nil },
          "confidence" => 0.98,
          "reason" => "The current message explicitly says the box was moved to the shelf."
        }
      ]
    }
    chat = FakeChat.new(content)
    proposer = Ai::StateUpdateProposers::RubyLlm.new(chat: chat)
    situation = situation_fixture("Я переніс синю коробку з гаража на полицю.")

    proposals = proposer.call(situation: situation, world_state: world)

    proposal = proposals.fetch(0)
    assert_equal "supersede", proposal.dig("update", "operation")
    assert_equal "location", proposal.dig("update", "predicate")
    assert_equal claim_id, proposal.dig("update", "target_claim_id")
    assert_equal({ "entity_id" => shelf_id }, proposal.dig("update", "object"))
    assert_equal true, proposal.dig("validation", "valid")
    assert_equal original, world
    assert_equal Ai::StateUpdateProposers::RubyLlm::SCHEMA, chat.schema
    assert_includes chat.instructions, "Do not invent entity IDs or claim IDs"
    assert_includes chat.prompt, "Я переніс синю коробку"
    assert_includes chat.prompt, claim_id
  end

  test "keeps an invalid model proposal visible but marks it invalid" do
    box_id = SecureRandom.uuid
    world = {
      "id" => SecureRandom.uuid,
      "entities" => [{ "id" => box_id, "kind" => "container", "label" => "box", "attributes" => {} }],
      "claims" => []
    }
    content = {
      "proposals" => [
        {
          "operation" => "assert",
          "predicate" => "location",
          "subject_id" => box_id,
          "target_claim_id" => nil,
          "key" => nil,
          "object" => { "type" => "entity", "entity_id" => SecureRandom.uuid, "value" => nil },
          "confidence" => 0.7,
          "reason" => "Proposed location."
        }
      ]
    }

    proposals = Ai::StateUpdateProposers::RubyLlm.new(chat: FakeChat.new(content)).call(
      situation: situation_fixture("Коробка тепер десь інде."),
      world_state: world
    )

    assert_equal false, proposals.first.dig("validation", "valid")
    assert_includes proposals.first.dig("validation", "error"), "object entity not found"
  end

  private

  def situation_fixture(raw_input)
    {
      "contract_version" => "0.1",
      "raw_input" => raw_input,
      "facts" => [{ "text" => raw_input, "source" => "user" }],
      "goals" => [],
      "constraints" => [],
      "uncertainties" => [],
      "hypotheses" => [],
      "entities" => []
    }
  end

  def world_fixture(box_id:, garage_id:, shelf_id:, claim_id:)
    {
      "contract_version" => "0.1",
      "id" => SecureRandom.uuid,
      "entities" => [
        { "id" => box_id, "kind" => "container", "label" => "blue box", "attributes" => {} },
        { "id" => garage_id, "kind" => "space", "label" => "garage", "attributes" => {} },
        { "id" => shelf_id, "kind" => "furniture", "label" => "shelf", "attributes" => {} }
      ],
      "claims" => [
        {
          "id" => claim_id,
          "predicate" => "location",
          "subject_id" => box_id,
          "object" => { "type" => "entity", "id" => garage_id },
          "status" => "active",
          "source" => "user",
          "confidence" => 1.0
        }
      ]
    }
  end
end
