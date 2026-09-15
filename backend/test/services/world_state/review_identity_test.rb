require "test_helper"
require "tmpdir"

class WorldStateReviewIdentityTest < ActiveSupport::TestCase
  test "merges an alias entity into a canonical entity and rewrites claim references" do
    Dir.mktmpdir do |dir|
      store = WorldState::Stores::JsonDirectory.new(path: dir)
      world = store.create
      canonical_id = SecureRandom.uuid
      alias_id = SecureRandom.uuid
      shelf_id = SecureRandom.uuid

      store.update(id: world.fetch("id")) do |state|
        state.fetch("entities") << { "id" => canonical_id, "kind" => "container", "label" => "синя коробка", "aliases" => [], "attributes" => {} }
        state.fetch("entities") << { "id" => alias_id, "kind" => "container", "label" => "box 3", "aliases" => ["коробка з кабелями"], "attributes" => { "color" => "blue" } }
        state.fetch("entities") << { "id" => shelf_id, "kind" => "furniture", "label" => "полиця", "aliases" => [], "attributes" => {} }
        state.fetch("claims") << {
          "id" => SecureRandom.uuid,
          "predicate" => "location",
          "subject_id" => alias_id,
          "object" => { "type" => "entity", "id" => shelf_id },
          "status" => "active"
        }
      end

      updated = WorldState::ReviewIdentity.new(
        world_id: world.fetch("id"),
        decision: "same_entity",
        canonical_entity_id: canonical_id,
        alias_entity_id: alias_id,
        reason: "User confirmed both names refer to the same box.",
        store: store
      ).call

      canonical = updated.fetch("entities").find { |entity| entity.fetch("id") == canonical_id }
      alias_entity = updated.fetch("entities").find { |entity| entity.fetch("id") == alias_id }
      claim = updated.fetch("claims").first

      assert_includes canonical.fetch("aliases"), "box 3"
      assert_includes canonical.fetch("aliases"), "коробка з кабелями"
      assert_equal "blue", canonical.dig("attributes", "color")
      assert_equal "merged", alias_entity.fetch("status")
      assert_equal canonical_id, alias_entity.fetch("merged_into_entity_id")
      assert_equal canonical_id, claim.fetch("subject_id")
      assert_equal alias_id, claim.dig("identity_rewrite", "from_entity_id")
      assert_equal canonical_id, claim.dig("identity_rewrite", "to_entity_id")
      assert_equal "same_entity", updated.fetch("identity_reviews").last.fetch("decision")
    end
  end

  test "rejects a merge that would create conflicting active singleton claims" do
    Dir.mktmpdir do |dir|
      store = WorldState::Stores::JsonDirectory.new(path: dir)
      world = store.create
      canonical_id = SecureRandom.uuid
      alias_id = SecureRandom.uuid
      shelf_a_id = SecureRandom.uuid
      shelf_b_id = SecureRandom.uuid

      store.update(id: world.fetch("id")) do |state|
        state.fetch("entities") << { "id" => canonical_id, "kind" => "container", "label" => "blue box", "aliases" => [], "attributes" => {} }
        state.fetch("entities") << { "id" => alias_id, "kind" => "container", "label" => "box 3", "aliases" => [], "attributes" => {} }
        state.fetch("entities") << { "id" => shelf_a_id, "kind" => "furniture", "label" => "shelf A", "aliases" => [], "attributes" => {} }
        state.fetch("entities") << { "id" => shelf_b_id, "kind" => "furniture", "label" => "shelf B", "aliases" => [], "attributes" => {} }
        state.fetch("claims") << active_location_claim(subject_id: canonical_id, object_id: shelf_a_id)
        state.fetch("claims") << active_location_claim(subject_id: alias_id, object_id: shelf_b_id)
      end

      error = assert_raises(ArgumentError) do
        WorldState::ReviewIdentity.new(
          world_id: world.fetch("id"),
          decision: "same_entity",
          canonical_entity_id: canonical_id,
          alias_entity_id: alias_id,
          store: store
        ).call
      end
      assert_equal "identity merge conflicts with active singleton claims", error.message

      unchanged = store.fetch(world.fetch("id"))
      alias_entity = unchanged.fetch("entities").find { |entity| entity.fetch("id") == alias_id }
      assert_nil alias_entity["status"]
      assert_nil alias_entity["merged_into_entity_id"]
      assert_empty unchanged.fetch("identity_reviews")
      assert_equal [canonical_id, alias_id], unchanged.fetch("claims").map { |claim| claim.fetch("subject_id") }
    end
  end

  test "coalesces equivalent singleton claims created by a safe identity merge" do
    Dir.mktmpdir do |dir|
      store = WorldState::Stores::JsonDirectory.new(path: dir)
      world = store.create
      canonical_id = SecureRandom.uuid
      alias_id = SecureRandom.uuid
      shelf_id = SecureRandom.uuid
      canonical_claim_id = SecureRandom.uuid
      alias_claim_id = SecureRandom.uuid

      store.update(id: world.fetch("id")) do |state|
        state.fetch("entities") << { "id" => canonical_id, "kind" => "container", "label" => "blue box", "aliases" => [], "attributes" => {} }
        state.fetch("entities") << { "id" => alias_id, "kind" => "container", "label" => "box 3", "aliases" => [], "attributes" => {} }
        state.fetch("entities") << { "id" => shelf_id, "kind" => "furniture", "label" => "shelf", "aliases" => [], "attributes" => {} }
        state.fetch("claims") << active_location_claim(id: canonical_claim_id, subject_id: canonical_id, object_id: shelf_id)
        state.fetch("claims") << active_location_claim(id: alias_claim_id, subject_id: alias_id, object_id: shelf_id)
      end

      updated = WorldState::ReviewIdentity.new(
        world_id: world.fetch("id"),
        decision: "same_entity",
        canonical_entity_id: canonical_id,
        alias_entity_id: alias_id,
        store: store
      ).call

      active = updated.fetch("claims").select do |claim|
        claim["status"] == "active" && claim["predicate"] == "location" && claim["subject_id"] == canonical_id
      end
      assert_equal [canonical_claim_id], active.map { |claim| claim.fetch("id") }

      duplicate = updated.fetch("claims").find { |claim| claim.fetch("id") == alias_claim_id }
      assert_equal "merged_duplicate", duplicate.fetch("status")
      assert_equal canonical_claim_id, duplicate.fetch("duplicate_of_claim_id")
      assert duplicate.fetch("ended_at").present?
      assert_equal alias_id, duplicate.dig("identity_rewrite", "from_entity_id")
      assert_equal canonical_id, duplicate.dig("identity_rewrite", "to_entity_id")
    end
  end

  test "records an idempotent different-entities decision and blocks a later merge" do
    Dir.mktmpdir do |dir|
      store = WorldState::Stores::JsonDirectory.new(path: dir)
      world = store.create
      left_id = SecureRandom.uuid
      right_id = SecureRandom.uuid

      store.update(id: world.fetch("id")) do |state|
        state.fetch("entities") << { "id" => left_id, "kind" => "container", "label" => "box 3", "aliases" => [], "attributes" => {} }
        state.fetch("entities") << { "id" => right_id, "kind" => "container", "label" => "коробка з кабелями", "aliases" => [], "attributes" => {} }
      end

      2.times do
        WorldState::ReviewIdentity.new(
          world_id: world.fetch("id"),
          decision: "different_entities",
          left_entity_id: left_id,
          right_entity_id: right_id,
          store: store
        ).call
      end

      assert_equal 1, store.fetch(world.fetch("id")).fetch("identity_reviews").size

      error = assert_raises(ArgumentError) do
        WorldState::ReviewIdentity.new(
          world_id: world.fetch("id"),
          decision: "same_entity",
          canonical_entity_id: left_id,
          alias_entity_id: right_id,
          store: store
        ).call
      end
      assert_equal "entities are explicitly different", error.message
    end
  end

  def active_location_claim(subject_id:, object_id:, id: SecureRandom.uuid)
    {
      "id" => id,
      "predicate" => "location",
      "subject_id" => subject_id,
      "object" => { "type" => "entity", "id" => object_id },
      "status" => "active"
    }
  end
end
