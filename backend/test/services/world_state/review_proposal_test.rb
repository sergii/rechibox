require "test_helper"
require "tmpdir"

class WorldStateReviewProposalTest < ActiveSupport::TestCase
  setup do
    @world_dir = Dir.mktmpdir
    @proposal_dir = Dir.mktmpdir
    @turn_dir = Dir.mktmpdir
    @world_store = WorldState::Stores::JsonDirectory.new(path: @world_dir)
    @proposal_store = WorldState::ProposalStores::JsonDirectory.new(path: @proposal_dir)
    @turn_store = Conversations::TurnStores::JsonDirectory.new(path: @turn_dir)
    @world = @world_store.create
    @box_id = SecureRandom.uuid
    @garage_id = SecureRandom.uuid
    @shelf_id = SecureRandom.uuid

    @world_store.update(id: @world.fetch("id")) do |world|
      world.fetch("entities") << { "id" => @box_id, "kind" => "container", "label" => "box", "attributes" => {} }
      world.fetch("entities") << { "id" => @garage_id, "kind" => "space", "label" => "garage", "attributes" => {} }
      world.fetch("entities") << { "id" => @shelf_id, "kind" => "furniture", "label" => "shelf", "attributes" => {} }
    end
  end

  teardown do
    FileUtils.remove_entry(@world_dir) if File.exist?(@world_dir)
    FileUtils.remove_entry(@proposal_dir) if File.exist?(@proposal_dir)
    FileUtils.remove_entry(@turn_dir) if File.exist?(@turn_dir)
  end

  test "accept applies a pending proposal and marks it accepted" do
    proposal = create_proposal(
      "operation" => "assert",
      "predicate" => "location",
      "subject_id" => @box_id,
      "object" => { "entity_id" => @garage_id }
    )

    result = review(proposal.fetch("id"), "accept")

    assert_equal "accepted", result.dig("proposal", "status")
    assert_equal "location", result.dig("world_state", "claims", 0, "predicate")
    assert_nil result["turn"]
  end

  test "accept marks proposal stale when world changed first" do
    proposal = create_proposal(
      "operation" => "assert",
      "predicate" => "location",
      "subject_id" => @box_id,
      "object" => { "entity_id" => @garage_id }
    )

    WorldState::ApplyUpdate.new(
      world_id: @world.fetch("id"),
      update: {
        "contract_version" => "0.1",
        "operation" => "assert",
        "predicate" => "location",
        "subject_id" => @box_id,
        "object" => { "entity_id" => @shelf_id }
      },
      store: @world_store
    ).call

    result = review(proposal.fetch("id"), "accept")

    assert_equal "stale", result.dig("proposal", "status")
    assert_equal false, result.dig("proposal", "validation", "valid")
  end

  test "reject preserves proposal without mutating world" do
    proposal = create_proposal(
      "operation" => "assert",
      "predicate" => "disposition",
      "subject_id" => @box_id,
      "object" => { "value" => "sell" }
    )

    result = WorldState::ReviewProposal.new(
      world_id: @world.fetch("id"),
      proposal_id: proposal.fetch("id"),
      action: "reject",
      rejection_reason: "Not now",
      proposal_store: @proposal_store,
      world_store: @world_store,
      turn_store: @turn_store
    ).call

    assert_equal "rejected", result.dig("proposal", "status")
    assert_equal "Not now", result.dig("proposal", "rejection_reason")
    assert_empty result.dig("world_state", "claims")
  end

  test "linked turn remains ready until every proposal is terminal" do
    conversation_id = SecureRandom.uuid
    message_id = SecureRandom.uuid
    turn = @turn_store.create(conversation_id: conversation_id, message_id: message_id)
    context = {
      "conversation_id" => conversation_id,
      "message_id" => message_id,
      "turn_id" => turn.fetch("id")
    }

    first = create_proposal(
      {
        "operation" => "assert",
        "predicate" => "location",
        "subject_id" => @box_id,
        "object" => { "entity_id" => @garage_id }
      },
      context: context
    )
    second = create_proposal(
      {
        "operation" => "assert",
        "predicate" => "ownership",
        "subject_id" => @box_id,
        "object" => { "entity_id" => @shelf_id }
      },
      context: context
    )
    mark_turn_ready(turn, [first, second])

    first_result = review(first.fetch("id"), "accept")
    assert_equal "ready_for_review", first_result.dig("turn", "status")
    assert_equal "ready_for_review", first_result.fetch("conversation_status")

    second_result = review(second.fetch("id"), "reject")
    assert_equal "completed", second_result.dig("turn", "status")
    assert_equal "completed", second_result.fetch("conversation_status")
    assert second_result.dig("turn", "completed_at").present?
  end

  test "stale linked proposal is terminal and completes its turn" do
    conversation_id = SecureRandom.uuid
    message_id = SecureRandom.uuid
    turn = @turn_store.create(conversation_id: conversation_id, message_id: message_id)
    proposal = create_proposal(
      {
        "operation" => "assert",
        "predicate" => "location",
        "subject_id" => @box_id,
        "object" => { "entity_id" => @garage_id }
      },
      context: {
        "conversation_id" => conversation_id,
        "message_id" => message_id,
        "turn_id" => turn.fetch("id")
      }
    )
    mark_turn_ready(turn, [proposal])

    WorldState::ApplyUpdate.new(
      world_id: @world.fetch("id"),
      update: {
        "contract_version" => "0.1",
        "operation" => "assert",
        "predicate" => "location",
        "subject_id" => @box_id,
        "object" => { "entity_id" => @shelf_id }
      },
      store: @world_store
    ).call

    result = review(proposal.fetch("id"), "accept")

    assert_equal "stale", result.dig("proposal", "status")
    assert_equal "completed", result.dig("turn", "status")
  end

  private

  def create_proposal(update, context: nil)
    validation = WorldState::ValidateUpdate.new(
      world: @world_store.fetch(@world.fetch("id")),
      update: { "contract_version" => "0.1" }.merge(update)
    ).call

    @proposal_store.create(
      world_id: @world.fetch("id"),
      proposer_mode: "test",
      context: context,
      proposal: {
        "update" => { "contract_version" => "0.1" }.merge(update),
        "reason" => "test",
        "validation" => validation
      }
    )
  end

  def mark_turn_ready(turn, proposals)
    @turn_store.update(conversation_id: turn.fetch("conversation_id"), id: turn.fetch("id")) do |record|
      record["status"] = "ready_for_review"
      record["proposal_ids"] = proposals.map { |proposal| proposal.fetch("id") }
    end
  end

  def review(id, action)
    WorldState::ReviewProposal.new(
      world_id: @world.fetch("id"),
      proposal_id: id,
      action: action,
      proposal_store: @proposal_store,
      world_store: @world_store,
      turn_store: @turn_store
    ).call
  end
end
