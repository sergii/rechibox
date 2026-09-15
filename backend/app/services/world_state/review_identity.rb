require "securerandom"
require "time"

module WorldState
  class ReviewIdentity
    CONTRACT_VERSION = "0.1"
    DECISIONS = %w[same_entity different_entities].freeze
    SINGLETON_PREDICATES = ApplyUpdate::SINGLETON_PREDICATES.freeze

    def initialize(world_id:, decision:, canonical_entity_id: nil, alias_entity_id: nil, left_entity_id: nil, right_entity_id: nil, reason: nil, store: Store.default)
      @world_id = world_id
      @decision = decision.to_s
      @canonical_entity_id = canonical_entity_id.to_s
      @alias_entity_id = alias_entity_id.to_s
      @left_entity_id = left_entity_id.to_s
      @right_entity_id = right_entity_id.to_s
      @reason = reason.to_s.strip
      @store = store
    end

    def call
      raise ArgumentError, "unsupported identity decision" unless DECISIONS.include?(@decision)

      @store.update(id: @world_id) do |world|
        world["identity_reviews"] ||= []

        review = case @decision
        when "same_entity"
          apply_same_entity(world)
        when "different_entities"
          apply_different_entities(world)
        end

        unless world.fetch("identity_reviews").any? { |existing| existing["id"] == review["id"] }
          world.fetch("identity_reviews") << review
        end
        world
      end
    end

    private

    def apply_same_entity(world)
      canonical = fetch_active_entity(world, @canonical_entity_id, field: "canonical_entity_id")
      alias_entity = fetch_active_entity(world, @alias_entity_id, field: "alias_entity_id")
      raise ArgumentError, "identity entities must be different" if canonical.fetch("id") == alias_entity.fetch("id")
      raise ArgumentError, "entity kinds are incompatible" unless compatible_kinds?(canonical, alias_entity)
      raise ArgumentError, "entities are explicitly different" if explicitly_different?(world, canonical.fetch("id"), alias_entity.fetch("id"))

      validate_singleton_integrity_after_merge!(
        world,
        from_id: alias_entity.fetch("id"),
        to_id: canonical.fetch("id")
      )

      canonical["aliases"] = merged_aliases(canonical, alias_entity)
      canonical["attributes"] = alias_entity.fetch("attributes", {}).merge(canonical.fetch("attributes", {}))
      canonical["updated_at"] = Time.now.utc.iso8601(6)

      alias_entity["status"] = "merged"
      alias_entity["merged_into_entity_id"] = canonical.fetch("id")
      alias_entity["merged_at"] = Time.now.utc.iso8601(6)

      changed_claim_ids = rewrite_claim_references(
        world,
        from_id: alias_entity.fetch("id"),
        to_id: canonical.fetch("id")
      )
      coalesce_equivalent_singletons!(world, changed_claim_ids: changed_claim_ids)

      build_review(
        "canonical_entity_id" => canonical.fetch("id"),
        "alias_entity_id" => alias_entity.fetch("id")
      )
    end

    def apply_different_entities(world)
      left = fetch_active_entity(world, @left_entity_id, field: "left_entity_id")
      right = fetch_active_entity(world, @right_entity_id, field: "right_entity_id")
      raise ArgumentError, "identity entities must be different" if left.fetch("id") == right.fetch("id")

      existing = Array(world["identity_reviews"]).find do |review|
        review["decision"] == "different_entities" && same_pair?(review, left.fetch("id"), right.fetch("id"))
      end
      return existing if existing

      build_review(
        "left_entity_id" => left.fetch("id"),
        "right_entity_id" => right.fetch("id")
      )
    end

    def fetch_active_entity(world, id, field:)
      raise ArgumentError, "#{field} must not be blank" if id.empty?

      entity = world.fetch("entities").find { |candidate| candidate.fetch("id") == id }
      raise ArgumentError, "entity not found" unless entity
      raise ArgumentError, "entity is already merged" if entity["status"] == "merged"

      entity
    end

    def compatible_kinds?(left, right)
      left_kind = left.fetch("kind", "other")
      right_kind = right.fetch("kind", "other")
      left_kind == right_kind || left_kind == "other" || right_kind == "other"
    end

    def explicitly_different?(world, left_id, right_id)
      Array(world["identity_reviews"]).any? do |review|
        review["decision"] == "different_entities" && same_pair?(review, left_id, right_id)
      end
    end

    def same_pair?(review, left_id, right_id)
      ids = [review["left_entity_id"], review["right_entity_id"]].compact.sort
      ids == [left_id, right_id].sort
    end

    def merged_aliases(canonical, alias_entity)
      names = [
        *Array(canonical["aliases"]),
        alias_entity["label"],
        *Array(alias_entity["aliases"])
      ].compact.map(&:to_s).map(&:strip).reject(&:empty?)

      canonical_label = canonical.fetch("label").to_s
      names.reject { |name| name.casecmp?(canonical_label) }.uniq { |name| name.downcase }
    end

    # Identity rewrites can collapse two previously independent singleton slots
    # onto one durable entity. Reject the merge before mutation when those slots
    # carry different active values. Identity confirmation is not evidence that
    # either physical-world claim should win.
    def validate_singleton_integrity_after_merge!(world, from_id:, to_id:)
      projected = active_singleton_claims(world).map do |claim|
        {
          touched: claim_references_entity?(claim, from_id),
          slot: projected_slot(claim, from_id: from_id, to_id: to_id),
          object: projected_object(claim, from_id: from_id, to_id: to_id)
        }
      end

      projected.group_by { |row| row.fetch(:slot) }.each_value do |rows|
        next unless rows.any? { |row| row.fetch(:touched) }
        next unless rows.map { |row| row.fetch(:object) }.uniq.size > 1

        raise ArgumentError, "identity merge conflicts with active singleton claims"
      end
    end

    def active_singleton_claims(world)
      world.fetch("claims").select do |claim|
        claim["status"] == "active" && SINGLETON_PREDICATES.include?(claim["predicate"])
      end
    end

    def projected_slot(claim, from_id:, to_id:)
      subject_id = claim["subject_id"] == from_id ? to_id : claim["subject_id"]
      [subject_id, claim["predicate"], claim["key"].to_s]
    end

    def projected_object(claim, from_id:, to_id:)
      object = claim.fetch("object", {})
      return object unless object["type"] == "entity" && object["id"] == from_id

      object.merge("id" => to_id)
    end

    def claim_references_entity?(claim, entity_id)
      claim["subject_id"] == entity_id ||
        (claim.dig("object", "type") == "entity" && claim.dig("object", "id") == entity_id)
    end

    def rewrite_claim_references(world, from_id:, to_id:)
      changed_claim_ids = []

      world.fetch("claims").each do |claim|
        changed = false

        if claim["subject_id"] == from_id
          claim["subject_id"] = to_id
          changed = true
        end

        if claim.dig("object", "type") == "entity" && claim.dig("object", "id") == from_id
          claim["object"]["id"] = to_id
          changed = true
        end

        next unless changed

        changed_claim_ids << claim.fetch("id")
        claim["identity_rewrite"] = {
          "from_entity_id" => from_id,
          "to_entity_id" => to_id,
          "rewritten_at" => Time.now.utc.iso8601(6)
        }
      end

      changed_claim_ids
    end

    # Equivalent singleton claims are safe to collapse after an identity merge.
    # Prefer an existing canonical claim over one changed by this rewrite and
    # preserve the duplicate as history instead of deleting it.
    def coalesce_equivalent_singletons!(world, changed_claim_ids:)
      active_singleton_claims(world)
        .group_by { |claim| [claim["subject_id"], claim["predicate"], claim["key"].to_s] }
        .each_value do |claims|
          next unless claims.size > 1
          next unless claims.any? { |claim| changed_claim_ids.include?(claim.fetch("id")) }
          next unless claims.map { |claim| claim.fetch("object", {}) }.uniq.size == 1

          winner = claims.min_by { |claim| changed_claim_ids.include?(claim.fetch("id")) ? 1 : 0 }
          claims.each do |claim|
            next if claim.equal?(winner)

            claim["status"] = "merged_duplicate"
            claim["duplicate_of_claim_id"] = winner.fetch("id")
            claim["ended_at"] = Time.now.utc.iso8601(6)
          end
        end
    end

    def build_review(extra)
      {
        "contract_version" => CONTRACT_VERSION,
        "id" => SecureRandom.uuid,
        "decision" => @decision,
        "reason" => @reason.empty? ? nil : @reason,
        "created_at" => Time.now.utc.iso8601(6)
      }.merge(extra).compact
    end
  end
end
