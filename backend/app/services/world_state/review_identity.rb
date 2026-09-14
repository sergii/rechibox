require "securerandom"
require "time"

module WorldState
  class ReviewIdentity
    CONTRACT_VERSION = "0.1"
    DECISIONS = %w[same_entity different_entities].freeze

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

      canonical["aliases"] = merged_aliases(canonical, alias_entity)
      canonical["attributes"] = alias_entity.fetch("attributes", {}).merge(canonical.fetch("attributes", {}))
      canonical["updated_at"] = Time.now.utc.iso8601(6)

      alias_entity["status"] = "merged"
      alias_entity["merged_into_entity_id"] = canonical.fetch("id")
      alias_entity["merged_at"] = Time.now.utc.iso8601(6)

      rewrite_claim_references(world, from_id: alias_entity.fetch("id"), to_id: canonical.fetch("id"))

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

    def rewrite_claim_references(world, from_id:, to_id:)
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

        claim["identity_rewrite"] = {
          "from_entity_id" => from_id,
          "to_entity_id" => to_id,
          "rewritten_at" => Time.now.utc.iso8601(6)
        }
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
