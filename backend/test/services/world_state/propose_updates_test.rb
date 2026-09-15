require "test_helper"
require "tmpdir"

class WorldStateProposeUpdatesTest < ActiveSupport::TestCase
  class FakeProposer < Ai::StateUpdateProposer
    def initialize(proposal)
      @proposal = proposal
    end

    def mode
      "fake"
    end

    def call(situation:, world_state:)
      raise ArgumentError, "situation must not be empty" if situation.empty?
      raise ArgumentError, "world state must not be empty" if world_state.empty?

      [@proposal]
    end
  end

  setup do
    @world_dir = Dir.mktmpdir
    @proposal_dir = Dir.mktmpdir
    @world_store = WorldState::Stores::JsonDirectory.new(path: @world_dir)
    @proposal_store = WorldState::ProposalStores::JsonDirectory.new(path: @proposal_dir)
    @world = @world_store.create
    @item_id = SecureRandom.uuid
    @box_id = SecureRandom.uuid

    @world_store.update(id: @world.fetch("id")) do |world|
      world.fetch("entities") << { "id" => @item_id, "kind" => "item", "label" => "cables", "attributes" => {} }
      world.fetch("entities") << { "id" => @box_id, "kind" => "container", "label" => "blue box", "attributes" => {} }
    end
  end

  teardown do
    FileUtils.remove_entry(@world_dir) if File.exist?(@world_dir)
    FileUtils.remove_entry(@proposal_dir) if File.exist?(@proposal_dir)
  end

  test "persists conversation turn provenance on generated proposals" do
    service, conversation_id, message_id, turn_id = build_service

    result = service.call

    proposal = result.fetch("proposals").sole
    assert_equal conversation_id, proposal.fetch("conversation_id")
    assert_equal message_id, proposal.fetch("message_id")
    assert_equal turn_id, proposal.fetch("turn_id")
  end

  test "prepare computes without durable proposal writes and persist commits the plan" do
    service, = build_service

    prepared = service.prepare

    assert_equal "fake", prepared.fetch("mode")
    assert_equal 1, prepared.fetch("proposed").size
    assert_empty @proposal_store.list(world_id: @world.fetch("id"))

    result = service.persist(prepared: prepared)

    assert_equal 1, result.fetch("proposals").size
    assert_equal 1, @proposal_store.list(world_id: @world.fetch("id")).size
  end

  private

  def build_service
    update = {
      "contract_version" => "0.1",
      "operation" => "assert",
      "predicate" => "location",
      "subject_id" => @item_id,
      "object" => { "entity_id" => @box_id }
    }
    validation = WorldState::ValidateUpdate.new(
      world: @world_store.fetch(@world.fetch("id")),
      update: update
    ).call
    proposer = FakeProposer.new(
      "update" => update,
      "reason" => "explicit user placement",
      "validation" => validation
    )
    conversation_id = SecureRandom.uuid
    message_id = SecureRandom.uuid
    turn_id = SecureRandom.uuid

    service = WorldState::ProposeUpdates.new(
      world_id: @world.fetch("id"),
      situation: { "facts" => [{ "text" => "The cables are in the blue box." }] },
      proposer: proposer,
      store: @world_store,
      proposal_store: @proposal_store,
      conversation_id: conversation_id,
      message_id: message_id,
      turn_id: turn_id
    )

    [service, conversation_id, message_id, turn_id]
  end
end
