require "securerandom"
require "time"

module WorldState
  module Stores
    class ActiveRecord < Store
      CONTRACT_VERSION = "0.1"

      def create
        now = Time.now.utc.iso8601(6)
        world = {
          "contract_version" => CONTRACT_VERSION,
          "id" => SecureRandom.uuid,
          "created_at" => now,
          "updated_at" => now,
          "entities" => [],
          "claims" => []
        }
        WorldDocument.create!(id: world.fetch("id"), payload: metadata_payload(world))
        world
      end

      def fetch(id)
        assemble(WorldDocument.find(id))
      rescue ::ActiveRecord::RecordNotFound
        raise KeyError, "world state not found"
      end

      def update(id:)
        world = nil

        ::ActiveRecord::Base.transaction do
          record = WorldDocument.lock.find(id)
          world = assemble(record)
          yield world
          world["updated_at"] = Time.now.utc.iso8601(6)

          sync_entities(record, Array(world["entities"]))
          sync_claims(record, Array(world["claims"]))
          record.update!(payload: metadata_payload(world))
        end

        world
      rescue ::ActiveRecord::RecordNotFound
        raise KeyError, "world state not found"
      end

      private

      def assemble(record)
        record.payload.deep_dup.merge(
          "entities" => record.world_entities.order(:position, :id).map { |entity| entity.payload.deep_dup },
          "claims" => record.world_claims.order(:position, :id).map { |claim| claim.payload.deep_dup }
        )
      end

      def metadata_payload(world)
        world.except("entities", "claims")
      end

      def sync_entities(record, entities)
        desired_ids = entities.map { |entity| entity.fetch("id") }
        record.world_entities.where.not(id: desired_ids).delete_all

        entities.each_with_index do |entity, position|
          attributes = {
            world_id: record.id,
            position: position,
            kind: entity.fetch("kind", "other"),
            label: entity.fetch("label", ""),
            status: entity["status"],
            payload: entity
          }
          WorldEntity.upsert(attributes.merge(id: entity.fetch("id")), unique_by: :id)
        end
      end

      def sync_claims(record, claims)
        desired_ids = claims.map { |claim| claim.fetch("id") }
        record.world_claims.where.not(id: desired_ids).delete_all

        claims.each_with_index do |claim, position|
          attributes = {
            world_id: record.id,
            position: position,
            predicate: claim.fetch("predicate", "fact"),
            subject_id: claim["subject_id"],
            status: claim["status"],
            source: claim["source"],
            object: claim["object"] || {},
            payload: claim
          }
          WorldClaim.upsert(attributes.merge(id: claim.fetch("id")), unique_by: :id)
        end
      end
    end
  end
end
