# This file is auto-generated from the current state of the database.

ActiveRecord::Schema[8.1].define(version: 2026_09_15_000100) do
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "conversation_documents", id: :uuid, force: :cascade do |t|
    t.uuid "world_id", null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["world_id"], name: "index_conversation_documents_on_world_id"
  end

  create_table "conversation_turn_documents", id: :uuid, force: :cascade do |t|
    t.uuid "conversation_id", null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id", "created_at"], name: "index_conversation_turn_documents_on_conversation_id_and_created_at"
  end

  create_table "state_update_proposal_documents", id: :uuid, force: :cascade do |t|
    t.uuid "world_id", null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["world_id", "created_at"], name: "index_state_update_proposal_documents_on_world_id_and_created_at"
  end

  create_table "world_clarification_documents", id: :uuid, force: :cascade do |t|
    t.uuid "world_id", null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["world_id", "created_at"], name: "index_world_clarification_documents_on_world_id_and_created_at"
  end

  create_table "world_documents", id: :uuid, force: :cascade do |t|
    t.jsonb "payload", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end
end
