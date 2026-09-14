class CreateRelationalWorldState < ActiveRecord::Migration[8.1]
  class MigrationWorldDocument < ActiveRecord::Base
    self.table_name = "world_documents"
  end

  class MigrationWorldEntity < ActiveRecord::Base
    self.table_name = "world_entities"
  end

  class MigrationWorldClaim < ActiveRecord::Base
    self.table_name = "world_claims"
  end

  def up
    create_table :world_entities, id: :uuid do |t|
      t.uuid :world_id, null: false
      t.integer :position, null: false, default: 0
      t.string :kind, null: false
      t.string :label, null: false
      t.string :status
      t.jsonb :payload, null: false, default: {}
      t.timestamps
    end
    add_foreign_key :world_entities, :world_documents, column: :world_id, on_delete: :cascade
    add_index :world_entities, :world_id
    add_index :world_entities, %i[world_id position]
    add_index :world_entities, %i[world_id kind]
    add_index :world_entities, %i[world_id status]
    add_index :world_entities, %i[world_id label]
    add_index :world_entities, :payload, using: :gin

    create_table :world_claims, id: :uuid do |t|
      t.uuid :world_id, null: false
      t.integer :position, null: false, default: 0
      t.string :predicate, null: false
      t.uuid :subject_id
      t.string :status
      t.string :source
      t.jsonb :object, null: false, default: {}
      t.jsonb :payload, null: false, default: {}
      t.timestamps
    end
    add_foreign_key :world_claims, :world_documents, column: :world_id, on_delete: :cascade
    add_index :world_claims, :world_id
    add_index :world_claims, %i[world_id position]
    add_index :world_claims, %i[world_id predicate]
    add_index :world_claims, %i[world_id subject_id]
    add_index :world_claims, %i[world_id status]
    add_index :world_claims, %i[world_id predicate status]
    add_index :world_claims, :object, using: :gin
    add_index :world_claims, :payload, using: :gin

    backfill_existing_worlds
  end

  def down
    drop_table :world_claims
    drop_table :world_entities
  end

  private

  def backfill_existing_worlds
    MigrationWorldDocument.reset_column_information
    MigrationWorldEntity.reset_column_information
    MigrationWorldClaim.reset_column_information

    MigrationWorldDocument.find_each do |world|
      payload = world.payload.deep_dup
      entities = Array(payload.delete("entities"))
      claims = Array(payload.delete("claims"))

      entities.each_with_index do |entity, position|
        MigrationWorldEntity.create!(
          id: entity.fetch("id"),
          world_id: world.id,
          position: position,
          kind: entity.fetch("kind", "other"),
          label: entity.fetch("label", ""),
          status: entity["status"],
          payload: entity
        )
      end

      claims.each_with_index do |claim, position|
        MigrationWorldClaim.create!(
          id: claim.fetch("id"),
          world_id: world.id,
          position: position,
          predicate: claim.fetch("predicate", "fact"),
          subject_id: claim["subject_id"],
          status: claim["status"],
          source: claim["source"],
          object: claim["object"] || {},
          payload: claim
        )
      end

      world.update_columns(payload: payload)
    end
  end
end
