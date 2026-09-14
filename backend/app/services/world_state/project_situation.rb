require "securerandom"

module WorldState
  class ProjectSituation
    ENTITY_KINDS = %w[space item container furniture person collection other].freeze

    def initialize(world_id:, situation:, conversation_id:, message_id:, store: Store.default)
      @world_id = world_id
      @situation = situation
      @conversation_id = conversation_id
      @message_id = message_id
      @store = store
    end

    def call
      @store.update(id: @world_id) do |world|
        project_entities(world)
        project_explicit_facts(world)
      end
    end

    private

    def project_entities(world)
      Array(@situation["entities"]).each do |entity|
        kind = entity["kind"].to_s
        next unless ENTITY_KINDS.include?(kind)

        label = entity["label"].to_s.strip
        next if label.empty?

        existing = world.fetch("entities").find do |candidate|
          candidate.fetch("kind") == kind && candidate.fetch("label").casecmp?(label)
        end

        if existing
          existing["attributes"] = existing.fetch("attributes", {}).merge(entity["attributes"] || {})
          existing["last_seen_message_id"] = @message_id
        else
          world.fetch("entities") << {
            "id" => SecureRandom.uuid,
            "kind" => kind,
            "label" => label,
            "attributes" => entity["attributes"] || {},
            "first_seen_message_id" => @message_id,
            "last_seen_message_id" => @message_id
          }
        end
      end
    end

    def project_explicit_facts(world)
      Array(@situation["facts"]).each do |fact|
        source = fact["source"].to_s
        next unless %w[user observed].include?(source)

        text = fact["text"].to_s.strip
        next if text.empty?
        next if duplicate_fact?(world, text)

        world.fetch("claims") << {
          "id" => SecureRandom.uuid,
          "predicate" => "fact",
          "value" => text,
          "status" => "active",
          "source" => source,
          "confidence" => fact["confidence"] || 1.0,
          "provenance" => {
            "conversation_id" => @conversation_id,
            "message_id" => @message_id
          }
        }
      end
    end

    def duplicate_fact?(world, text)
      world.fetch("claims").any? do |claim|
        claim["predicate"] == "fact" && claim["status"] == "active" && claim["value"].to_s.casecmp?(text)
      end
    end
  end
end
