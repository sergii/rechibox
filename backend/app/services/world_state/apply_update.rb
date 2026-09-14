require "securerandom"
require "time"

module WorldState
  class ApplyUpdate
    CONTRACT_VERSION = "0.1"
    OPERATIONS = %w[assert correct supersede].freeze
    PREDICATES = %w[ownership custody location disposition contains attribute].freeze
    SINGLETON_PREDICATES = %w[custody location disposition attribute].freeze
    SOURCES = %w[user observed inferred imported].freeze

    def initialize(world_id:, update:, store: Store.default)
      @world_id = world_id
      @update = update.to_h.transform_keys(&:to_s)
      @store = store
    end

    def call
      validate_contract!

      @store.update(id: @world_id) do |world|
        validate_subject!(world)
        validate_object!(world)

        case @update.fetch("operation")
        when "assert"
          assert_claim(world)
        when "correct"
          replace_claim(world, terminal_status: "corrected")
        when "supersede"
          replace_claim(world, terminal_status: "superseded")
        end
      end
    end

    private

    def validate_contract!
      version = @update.fetch("contract_version", CONTRACT_VERSION).to_s
      raise ArgumentError, "unsupported state update contract" unless version == CONTRACT_VERSION

      operation = @update.fetch("operation").to_s
      predicate = @update.fetch("predicate").to_s
      raise ArgumentError, "unsupported state update operation" unless OPERATIONS.include?(operation)
      raise ArgumentError, "unsupported state update predicate" unless PREDICATES.include?(predicate)

      subject_id = @update.fetch("subject_id").to_s
      raise ArgumentError, "subject_id must not be blank" if subject_id.empty?

      object = @update.fetch("object")
      raise ArgumentError, "object must be a Hash" unless object.is_a?(Hash)

      key = @update["key"].to_s.strip
      raise ArgumentError, "attribute updates require key" if predicate == "attribute" && key.empty?

      source = @update.fetch("source", "user").to_s
      raise ArgumentError, "unsupported state update source" unless SOURCES.include?(source)

      confidence = Float(@update.fetch("confidence", 1.0))
      raise ArgumentError, "confidence must be between 0 and 1" unless confidence.between?(0.0, 1.0)

      if %w[correct supersede].include?(operation)
        target = @update.fetch("target_claim_id").to_s
        raise ArgumentError, "target_claim_id must not be blank" if target.empty?
      end
    rescue TypeError, ArgumentError => e
      raise e if e.message.start_with?("unsupported", "attribute", "confidence", "subject", "object", "target")
      raise ArgumentError, "confidence must be between 0 and 1"
    end

    def validate_subject!(world)
      return if entity_exists?(world, @update.fetch("subject_id"))

      raise ArgumentError, "subject entity not found"
    end

    def validate_object!(world)
      object = normalized_object
      return unless object["type"] == "entity"
      return if entity_exists?(world, object.fetch("id"))

      raise ArgumentError, "object entity not found"
    end

    def entity_exists?(world, id)
      world.fetch("entities").any? { |entity| entity.fetch("id") == id }
    end

    def normalized_object
      object = @update.fetch("object").to_h.transform_keys(&:to_s)
      if object.key?("entity_id")
        id = object.fetch("entity_id").to_s
        raise ArgumentError, "object entity_id must not be blank" if id.empty?
        { "type" => "entity", "id" => id }
      elsif object.key?("value")
        { "type" => "value", "value" => object["value"] }
      else
        raise ArgumentError, "object requires entity_id or value"
      end
    end

    def assert_claim(world)
      existing = active_claims_for_slot(world)
      object = normalized_object

      return world if existing.any? { |claim| claim["object"] == object }

      if singleton_predicate? && existing.any?
        raise ArgumentError, "active claim exists; use correct or supersede"
      end

      world.fetch("claims") << build_claim
      world
    end

    def replace_claim(world, terminal_status:)
      target = world.fetch("claims").find { |claim| claim.fetch("id") == @update.fetch("target_claim_id") }
      raise ArgumentError, "target claim not found" unless target
      raise ArgumentError, "target claim is not active" unless target["status"] == "active"
      raise ArgumentError, "target claim subject does not match" unless target["subject_id"] == @update.fetch("subject_id")
      raise ArgumentError, "target claim predicate does not match" unless target["predicate"] == @update.fetch("predicate")
      raise ArgumentError, "target claim key does not match" unless target["key"].to_s == normalized_key.to_s

      replacement = build_claim("replaces_claim_id" => target.fetch("id"))
      target["status"] = terminal_status
      target["replaced_by_claim_id"] = replacement.fetch("id")
      target["ended_at"] = Time.now.utc.iso8601(6)
      world.fetch("claims") << replacement
      world
    end

    def active_claims_for_slot(world)
      world.fetch("claims").select do |claim|
        claim["status"] == "active" &&
          claim["subject_id"] == @update.fetch("subject_id") &&
          claim["predicate"] == @update.fetch("predicate") &&
          claim["key"].to_s == normalized_key.to_s
      end
    end

    def singleton_predicate?
      SINGLETON_PREDICATES.include?(@update.fetch("predicate"))
    end

    def build_claim(extra = {})
      {
        "id" => SecureRandom.uuid,
        "predicate" => @update.fetch("predicate"),
        "subject_id" => @update.fetch("subject_id"),
        "object" => normalized_object,
        "key" => normalized_key,
        "status" => "active",
        "source" => @update.fetch("source", "user"),
        "confidence" => Float(@update.fetch("confidence", 1.0)),
        "asserted_at" => Time.now.utc.iso8601(6),
        "provenance" => @update.fetch("provenance", {})
      }.merge(extra).compact
    end

    def normalized_key
      value = @update["key"].to_s.strip
      value.empty? ? nil : value
    end
  end
end
