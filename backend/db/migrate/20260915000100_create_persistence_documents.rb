class CreatePersistenceDocuments < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")

    create_table :world_documents, id: :uuid do |t|
      t.jsonb :payload, null: false, default: {}
      t.timestamps
    end

    create_table :conversation_documents, id: :uuid do |t|
      t.uuid :world_id, null: false
      t.jsonb :payload, null: false, default: {}
      t.timestamps
    end
    add_index :conversation_documents, :world_id

    create_table :conversation_turn_documents, id: :uuid do |t|
      t.uuid :conversation_id, null: false
      t.jsonb :payload, null: false, default: {}
      t.timestamps
    end
    add_index :conversation_turn_documents, [:conversation_id, :created_at]

    create_table :state_update_proposal_documents, id: :uuid do |t|
      t.uuid :world_id, null: false
      t.jsonb :payload, null: false, default: {}
      t.timestamps
    end
    add_index :state_update_proposal_documents, [:world_id, :created_at]

    create_table :world_clarification_documents, id: :uuid do |t|
      t.uuid :world_id, null: false
      t.jsonb :payload, null: false, default: {}
      t.timestamps
    end
    add_index :world_clarification_documents, [:world_id, :created_at]
  end
end
