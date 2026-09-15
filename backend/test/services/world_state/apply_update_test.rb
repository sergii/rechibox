require "test_helper"
require "tmpdir"

class WorldStateApplyUpdateTest < ActiveSupport::TestCase
  setup do
    @dir = Dir.mktmpdir
    @store = WorldState::Stores::JsonDirectory.new(path: @dir)
    @world = @store.create
    @box_id = SecureRandom.uuid
    @garage_id = SecureRandom.uuid
    @store.update(id: @world.fetch("id")) do |world|
      world.fetch("entities") << { "id" => @box_id, "kind" => "container", "label" => "blue box", "attributes" => {} }
      world.fetch("entities") << { "id" => @garage_id, "kind" => "space", "label" => "garage", "attributes" => {} }
    end
  end

  teardown do
    FileUtils.remove_entry(@dir) if @dir && File.exist?(@dir)
  end

  test "asserts a typed relation" do
    updated = apply(
      "operation" => "assert",
      "predicate" => "location",
      "subject_id" => @box_id,
      "object" => { "entity_id" => @garage_id }
    )

    claim = updated.fetch("claims").last
    assert_equal "location", claim.fetch("predicate")
    assert_equal @box_id, claim.fetch("subject_id")
    assert_equal({ "type" => "entity", "id" => @garage_id }, claim.fetch("object"))
    assert_equal "active", claim.fetch("status")
  end

  test "identical assert is idempotent" do
    update = {
      "operation" => "assert",
      "predicate" => "location",
      "subject_id" => @box_id,
      "object" => { "entity_id" => @garage_id }
    }

    apply(update)
    updated = apply(update)

    assert_equal 1, updated.fetch("claims").count { |claim| claim["predicate"] == "location" }
  end

  test "singleton predicates require an explicit transition when active value conflicts" do
    apply(
      "operation" => "assert",
      "predicate" => "disposition",
      "subject_id" => @box_id,
      "object" => { "value" => "keep" }
    )

    error = assert_raises(ArgumentError) do
      apply(
        "operation" => "assert",
        "predicate" => "disposition",
        "subject_id" => @box_id,
        "object" => { "value" => "sell" }
      )
    end

    assert_includes error.message, "correct or supersede"
  end

  test "correction preserves history and marks the previous assertion as wrong" do
    first = apply(
      "operation" => "assert",
      "predicate" => "disposition",
      "subject_id" => @box_id,
      "object" => { "value" => "keep" }
    ).fetch("claims").last

    updated = apply(
      "operation" => "correct",
      "predicate" => "disposition",
      "subject_id" => @box_id,
      "target_claim_id" => first.fetch("id"),
      "object" => { "value" => "sell" }
    )

    previous = updated.fetch("claims").find { |claim| claim.fetch("id") == first.fetch("id") }
    replacement = updated.fetch("claims").last
    assert_equal "corrected", previous.fetch("status")
    assert_equal replacement.fetch("id"), previous.fetch("replaced_by_claim_id")
    assert_equal first.fetch("id"), replacement.fetch("replaces_claim_id")
    assert_equal "sell", replacement.dig("object", "value")
  end

  test "supersede represents a real state change rather than a correction" do
    first = apply(
      "operation" => "assert",
      "predicate" => "location",
      "subject_id" => @box_id,
      "object" => { "entity_id" => @garage_id }
    ).fetch("claims").last

    shelf_id = SecureRandom.uuid
    @store.update(id: @world.fetch("id")) do |world|
      world.fetch("entities") << { "id" => shelf_id, "kind" => "furniture", "label" => "shelf", "attributes" => {} }
    end

    updated = apply(
      "operation" => "supersede",
      "predicate" => "location",
      "subject_id" => @box_id,
      "target_claim_id" => first.fetch("id"),
      "object" => { "entity_id" => shelf_id }
    )

    previous = updated.fetch("claims").find { |claim| claim.fetch("id") == first.fetch("id") }
    assert_equal "superseded", previous.fetch("status")
    assert previous.fetch("ended_at").present?
  end

  test "attribute updates require an explicit key" do
    error = assert_raises(ArgumentError) do
      apply(
        "operation" => "assert",
        "predicate" => "attribute",
        "subject_id" => @box_id,
        "object" => { "value" => "blue" }
      )
    end

    assert_includes error.message, "require key"
  end

  test "rejects a merged tombstone as the update subject" do
    alias_id = merged_entity_id

    error = assert_raises(ArgumentError) do
      apply(
        "operation" => "assert",
        "predicate" => "location",
        "subject_id" => alias_id,
        "object" => { "entity_id" => @garage_id }
      )
    end

    assert_includes error.message, "subject entity is merged"
    assert_includes error.message, "canonical entity id"
  end

  test "rejects a merged tombstone as an entity-valued object" do
    alias_id = merged_entity_id

    error = assert_raises(ArgumentError) do
      apply(
        "operation" => "assert",
        "predicate" => "contains",
        "subject_id" => @box_id,
        "object" => { "entity_id" => alias_id }
      )
    end

    assert_includes error.message, "object entity is merged"
    assert_includes error.message, "canonical entity id"
  end

  private

  def apply(update)
    WorldState::ApplyUpdate.new(
      world_id: @world.fetch("id"),
      update: { "contract_version" => "0.1" }.merge(update),
      store: @store
    ).call
  end

  def merged_entity_id
    alias_id = SecureRandom.uuid
    @store.update(id: @world.fetch("id")) do |world|
      world.fetch("entities") << {
        "id" => alias_id,
        "kind" => "container",
        "label" => "old blue box",
        "status" => "merged",
        "merged_into_entity_id" => @box_id,
        "attributes" => {}
      }
    end
    alias_id
  end
end
