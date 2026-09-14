require "test_helper"
require "tmpdir"

class WorldStateReviewProposalTest < ActiveSupport::TestCase
  setup do
    @world_dir = Dir.mktmpdir
    @proposal_dir = Dir.mktmpdir
    @world_store = WorldState::Stores::JsonDirectory.new(path: @world_dir)
    @proposal_store = WorldState::ProposalStores::JsonDirectory.new(path: @proposal_dir)
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
      world_store: @world_store
    ).call

    assert_equal "rejected", result.dig("proposal", "status")
    assert_equal "Not now", result.dig("proposal", "rejection_reason")
    assert_empty result.dig("world_state", "claims")
  end

  private

  def create_proposal(update)
    validation = WorldState::ValidateUpdate.new(
      world: @world_store.fetch(@world.fetch("id")),
      update: { "contract_version" => "0.1" }.merge(update)
    ).call

    @proposal_store.create(
      world_id: @world.fetch("id"),
      proposer_mode: "test",
      proposal: {
        "update" => { "contract_version" => "0.1" }.merge(update),
        "reason" => "test",
        "validation" => validation
      }
    )
  end

  def review(id, action)
    WorldState::ReviewProposal.new(
      world_id: @world.fetch("id"),
      proposal_id: id,
      action: action,
      proposal_store: @proposal_store,
      world_store: @world_store
    ).call
  end
end
