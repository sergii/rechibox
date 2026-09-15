require "test_helper"
require "tmpdir"

class WorldStateNaturalLocationCommandTest < ActiveSupport::TestCase
  setup do
    @world_dir = Dir.mktmpdir
    @proposal_dir = Dir.mktmpdir
    @store = WorldState::Stores::JsonDirectory.new(path: @world_dir)
    @proposal_store = WorldState::ProposalStores::JsonDirectory.new(path: @proposal_dir)
    @world = @store.create
    @cables_id = SecureRandom.uuid
    @box_id = SecureRandom.uuid
    @shelf_id = SecureRandom.uuid

    @store.update(id: @world.fetch("id")) do |world|
      world.fetch("entities") << { "id" => @cables_id, "kind" => "item", "label" => "зарядки", "attributes" => {} }
      world.fetch("entities") << { "id" => @box_id, "kind" => "container", "label" => "синя коробка", "attributes" => {} }
      world.fetch("entities") << { "id" => @shelf_id, "kind" => "furniture", "label" => "полиця", "attributes" => {} }
    end
  end

  teardown do
    FileUtils.remove_entry(@world_dir) if File.exist?(@world_dir)
    FileUtils.remove_entry(@proposal_dir) if File.exist?(@proposal_dir)
  end

  test "proposes an explicit Ukrainian location assertion without mutating world" do
    result = command("Я поклав зарядки в синю коробку")

    assert_equal "ready_for_review", result.fetch("status")
    proposal = result.fetch("proposal")
    assert_equal "pending", proposal.fetch("status")
    assert_equal "assert", proposal.dig("update", "operation")
    assert_equal "location", proposal.dig("update", "predicate")
    assert_equal @cables_id, proposal.dig("update", "subject_id")
    assert_equal({ "entity_id" => @box_id }, proposal.dig("update", "object"))
    assert_equal "user", proposal.dig("update", "source")
    assert_empty @store.fetch(@world.fetch("id")).fetch("claims")
  end

  test "proposes supersede when explicit statement moves an entity" do
    WorldState::ApplyUpdate.new(
      world_id: @world.fetch("id"),
      store: @store,
      update: {
        "operation" => "assert",
        "predicate" => "location",
        "subject_id" => @cables_id,
        "object" => { "entity_id" => @shelf_id },
        "source" => "user"
      }
    ).call
    old_claim = @store.fetch(@world.fetch("id")).fetch("claims").sole

    result = command("Я перемістив зарядки у синю коробку")

    assert_equal "ready_for_review", result.fetch("status")
    assert_equal "supersede", result.dig("proposal", "update", "operation")
    assert_equal old_claim.fetch("id"), result.dig("proposal", "update", "target_claim_id")
  end

  test "does not create a proposal when location is already current" do
    WorldState::ApplyUpdate.new(
      world_id: @world.fetch("id"),
      store: @store,
      update: {
        "operation" => "assert",
        "predicate" => "location",
        "subject_id" => @cables_id,
        "object" => { "entity_id" => @box_id },
        "source" => "user"
      }
    ).call

    result = command("Я поклала зарядки в синю коробку")

    assert_equal "already_current", result.fetch("status")
    assert_empty @proposal_store.list(world_id: @world.fetch("id"))
  end

  test "supports bounded English wording" do
    @store.update(id: @world.fetch("id")) do |world|
      world.fetch("entities").find { |entity| entity.fetch("id") == @cables_id }["label"] = "chargers"
      world.fetch("entities").find { |entity| entity.fetch("id") == @box_id }["label"] = "blue box"
    end

    result = command("I put chargers in blue box")

    assert_equal "ready_for_review", result.fetch("status")
    assert_equal @box_id, result.dig("proposal", "update", "object", "entity_id")
  end

  test "fails closed when wording is outside the bounded command grammar" do
    result = command("Може зарядки десь у синій коробці")

    assert_equal "unsupported", result.fetch("status")
    assert_empty @proposal_store.list(world_id: @world.fetch("id"))
  end

  test "fails closed when an entity cannot be resolved" do
    result = command("Я поклав невідому річ у синю коробку")

    assert_equal "unresolved", result.fetch("status")
    assert_empty @proposal_store.list(world_id: @world.fetch("id"))
  end

  private

  def command(message)
    WorldState::NaturalLocationCommand.new(
      world_id: @world.fetch("id"),
      store: @store,
      proposal_store: @proposal_store
    ).call(message: message)
  end
end
