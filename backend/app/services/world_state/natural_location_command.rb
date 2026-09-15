module WorldState
  class NaturalLocationCommand
    CONTRACT_VERSION = "0.1"

    UK_PATTERNS = [
      /\A(?:я\s+)?(?:поклав|поклала|поклали|поставив|поставила|поставили|переклав|переклала|переклали|перемістив|перемістила|перемістили)\s+(.+?)\s+(?:у|в|до)\s+(.+?)\s*[.!?]?\z/iu
    ].freeze
    EN_PATTERNS = [
      /\A(?:i\s+)?(?:put|placed|moved)\s+(.+?)\s+(?:in|into|to)\s+(.+?)\s*[.!?]?\z/iu
    ].freeze

    def initialize(
      world_id:,
      store: Store.default,
      proposal_store: ProposalStore.default
    )
      @world_id = world_id
      @store = store
      @proposal_store = proposal_store
    end

    def call(message:)
      text = message.to_s.strip
      raise ArgumentError, "message must not be blank" if text.empty?

      parsed = parse(text)
      return result(status: "unsupported", message: text) unless parsed

      world = @store.fetch(@world_id)
      resolution = ResolveEntities.new(
        world: world,
        situation: {
          "entities" => [
            { "ref" => "E1", "kind" => "other", "label" => parsed.fetch("subject_label") },
            { "ref" => "E2", "kind" => "other", "label" => parsed.fetch("location_label") }
          ]
        }
      ).call
      subject, location = resolution.fetch("resolutions")

      unless subject.fetch("status") == "resolved" && location.fetch("status") == "resolved"
        return result(
          status: resolution_status(subject, location),
          message: text,
          parsed: parsed,
          resolution: resolution
        )
      end

      subject_id = subject.fetch("durable_entity_id")
      location_id = location.fetch("durable_entity_id")
      active_location = active_location_claim(world, subject_id)

      if active_location&.dig("object", "type") == "entity" && active_location.dig("object", "id") == location_id
        return result(
          status: "already_current",
          message: text,
          parsed: parsed,
          resolution: resolution,
          current_claim_id: active_location.fetch("id")
        )
      end

      update = build_update(
        subject_id: subject_id,
        location_id: location_id,
        active_location: active_location,
        message: text
      )
      validation = ValidateUpdate.new(world: world, update: update).call
      raise ArgumentError, validation.fetch("error") unless validation.fetch("valid")

      proposal = @proposal_store.create(
        world_id: @world_id,
        proposer_mode: "deterministic_location_command",
        proposal: {
          "update" => update,
          "reason" => "Explicit user statement that an entity was placed or moved to a location.",
          "validation" => validation
        }
      )

      result(
        status: "ready_for_review",
        message: text,
        parsed: parsed,
        resolution: resolution,
        proposal: proposal
      )
    end

    private

    def parse(text)
      pattern = (UK_PATTERNS + EN_PATTERNS).find { |candidate| candidate.match?(text) }
      return unless pattern

      match = pattern.match(text)
      {
        "intent" => "set_location",
        "subject_label" => clean_label(match[1]),
        "location_label" => clean_label(match[2])
      }
    end

    def clean_label(value)
      value.to_s.strip.sub(/[.!?]+\z/, "").strip
    end

    def active_location_claim(world, subject_id)
      Array(world["claims"]).find do |claim|
        claim["status"] == "active" &&
          claim["predicate"] == "location" &&
          claim["subject_id"] == subject_id
      end
    end

    def build_update(subject_id:, location_id:, active_location:, message:)
      update = {
        "contract_version" => "0.1",
        "operation" => active_location ? "supersede" : "assert",
        "predicate" => "location",
        "subject_id" => subject_id,
        "object" => { "entity_id" => location_id },
        "source" => "user",
        "confidence" => 1.0,
        "provenance" => {
          "source" => "natural_location_command",
          "message" => message
        }
      }
      update["target_claim_id"] = active_location.fetch("id") if active_location
      update
    end

    def resolution_status(subject, location)
      return "ambiguous" if [subject, location].any? { |row| row.fetch("status") == "ambiguous" }

      "unresolved"
    end

    def result(status:, message:, **extra)
      {
        "contract_version" => CONTRACT_VERSION,
        "world_id" => @world_id,
        "mode" => "deterministic",
        "status" => status,
        "message" => message
      }.merge(extra.transform_keys(&:to_s))
    end
  end
end
