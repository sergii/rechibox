require "securerandom"
require "time"

module WorldState
  class ImportInventorySnapshot
    CONTRACT_VERSION = "0.1"
    ENTITY_KINDS = %w[space item container furniture person collection other].freeze
    SOURCE_REF_ATTRIBUTE = "rechibox_source_ref"

    def initialize(world_id:, snapshot:, store: Store.default)
      @world_id = world_id
      @snapshot = snapshot.to_h.transform_keys(&:to_s)
      @store = store
    end

    def call
      validate_snapshot!

      result = nil
      @store.update(id: @world_id) do |world|
        result = import(world)
        world
      end
      result
    end

    private

    def validate_snapshot!
      version = @snapshot.fetch("contract_version", CONTRACT_VERSION).to_s
      raise ArgumentError, "unsupported inventory snapshot contract" unless version == CONTRACT_VERSION

      entities = @snapshot.fetch("entities")
      raise ArgumentError, "entities must be an Array" unless entities.is_a?(Array)

      refs = entities.map { |entity| normalized_entity(entity).fetch("source_ref") }
      raise ArgumentError, "inventory snapshot source_ref values must be unique" unless refs.uniq.length == refs.length
    rescue KeyError => e
      raise ArgumentError, "missing inventory snapshot field: #{e.key || 'unknown'}"
    end

    def import(world)
      rows = @snapshot.fetch("entities").map { |entity| normalized_entity(entity) }
      by_ref = {}
      created = 0
      updated = 0

      rows.each do |row|
        entity = entity_for_source_ref(world, row.fetch("source_ref"))
        if entity
          update_entity!(entity, row)
          updated += 1
        else
          entity = build_entity(row)
          world.fetch("entities") << entity
          created += 1
        end
        by_ref[row.fetch("source_ref")] = entity
      end

      location_changes = 0
      conflicts = []
      rows.each do |row|
        next unless row.key?("location_ref")

        subject = by_ref.fetch(row.fetch("source_ref"))
        target_ref = row["location_ref"]
        target = target_ref.nil? ? nil : by_ref[target_ref]
        raise ArgumentError, "location_ref must reference an entity in the same snapshot" if target_ref && !target

        change = sync_location!(world, subject: subject, target: target, source_ref: row.fetch("source_ref"))
        location_changes += 1 if change == :changed
        conflicts << row.fetch("source_ref") if change == :conflict
      end

      {
        "contract_version" => CONTRACT_VERSION,
        "world_id" => world.fetch("id"),
        "created_entities" => created,
        "updated_entities" => updated,
        "location_changes" => location_changes,
        "conflicts" => conflicts,
        "entities" => by_ref.transform_values { |entity| entity.fetch("id") }
      }
    end

    def normalized_entity(value)
      raise ArgumentError, "inventory snapshot entity must be a Hash" unless value.is_a?(Hash)

      row = value.to_h.transform_keys(&:to_s)
      source_ref = row.fetch("source_ref").to_s.strip
      kind = row.fetch("kind").to_s
      label = row.fetch("label").to_s.strip
      raise ArgumentError, "source_ref must not be blank" if source_ref.empty?
      raise ArgumentError, "unsupported inventory entity kind" unless ENTITY_KINDS.include?(kind)
      raise ArgumentError, "label must not be blank" if label.empty?

      normalized = {
        "source_ref" => source_ref,
        "kind" => kind,
        "label" => label,
        "attributes" => row.fetch("attributes", {}).to_h.transform_keys(&:to_s)
      }
      normalized["location_ref"] = normalized_location_ref(row["location_ref"]) if row.key?("location_ref")
      normalized
    rescue KeyError => e
      raise ArgumentError, "missing inventory entity field: #{e.key || 'unknown'}"
    end

    def normalized_location_ref(value)
      return nil if value.nil?

      ref = value.to_s.strip
      raise ArgumentError, "location_ref must not be blank" if ref.empty?
      ref
    end

    def entity_for_source_ref(world, source_ref)
      world.fetch("entities").find do |entity|
        entity.fetch("attributes", {})[SOURCE_REF_ATTRIBUTE] == source_ref
      end
    end

    def update_entity!(entity, row)
      raise ArgumentError, "cannot import into merged entity" if entity["status"] == "merged"
      raise ArgumentError, "inventory source_ref kind changed" unless entity.fetch("kind") == row.fetch("kind")

      old_label = entity.fetch("label").to_s
      new_label = row.fetch("label")
      unless old_label.casecmp?(new_label)
        entity["aliases"] = (Array(entity["aliases"]) + [old_label]).map(&:to_s).uniq
        entity["label"] = new_label
      end
      entity["attributes"] = entity.fetch("attributes", {}).merge(row.fetch("attributes")).merge(
        SOURCE_REF_ATTRIBUTE => row.fetch("source_ref")
      )
    end

    def build_entity(row)
      {
        "id" => SecureRandom.uuid,
        "kind" => row.fetch("kind"),
        "label" => row.fetch("label"),
        "aliases" => [],
        "attributes" => row.fetch("attributes").merge(SOURCE_REF_ATTRIBUTE => row.fetch("source_ref"))
      }
    end

    def sync_location!(world, subject:, target:, source_ref:)
      active = world.fetch("claims").select do |claim|
        claim["status"] == "active" && claim["predicate"] == "location" && claim["subject_id"] == subject.fetch("id")
      end
      target_object = target && { "type" => "entity", "id" => target.fetch("id") }
      return :unchanged if target_object && active.any? { |claim| claim["object"] == target_object }

      protected_claims = active.reject { |claim| claim["source"] == "imported" }
      return :conflict if protected_claims.any?

      now = Time.now.utc.iso8601(6)
      active.each do |claim|
        claim["status"] = "superseded"
        claim["ended_at"] = now
      end
      return active.empty? ? :unchanged : :changed unless target_object

      replacement = {
        "id" => SecureRandom.uuid,
        "predicate" => "location",
        "subject_id" => subject.fetch("id"),
        "object" => target_object,
        "status" => "active",
        "source" => "imported",
        "confidence" => 1.0,
        "asserted_at" => now,
        "provenance" => {
          "source" => "mobile_inventory",
          "source_ref" => source_ref
        }
      }
      previous = active.last
      if previous
        replacement["replaces_claim_id"] = previous.fetch("id")
        previous["replaced_by_claim_id"] = replacement.fetch("id")
      end
      world.fetch("claims") << replacement
      :changed
    end
  end
end
