# This file is auto-generated from the current state of the database.

ActiveRecord::Schema[8.1].define(version: 2026_09_15_000200) do
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

  create_table "world_claims", id: :uuid, force: :cascade do |t|
    t.uuid "world_id", null: false
    t.integer "position", default: 0, null: false
    t.string "predicate", null: false
    t.uuid "subject_id"
    t.string "status"
    t.string "source"
    t.jsonb "object", default: {}, null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["object"], name: "index_world_claims_on_object", using: :gin
    t.index ["payload"], name: "index_world_claims_on_payload", using: :gin
    t.index ["world_id", "position"], name: "index_world_claims_on_world_id_and_position"
    t.index ["world_id", "predicate", "status"], name: "index_world_claims_on_world_id_and_predicate_and_status"
    t.index ["world_id", "predicate"], name: "index_world_claims_on_world_id_and_predicate"
    t.index ["world_id", "status"], name: "index_world_claims_on_world_id_and_status"
    t.index ["world_id", "subject_id"], name: "index_world_claims_on_world_id_and_subject_id"
    t.index ["world_id"], name: "index_world_claims_on_world_id"
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

  create_table "world_entities", id: :uuid, force: :cascade do |t|
    t.uuid "world_id", null: false
    t.integer "position", default: 0, null: false
    t.string "kind", null: false
    t.string "label", null: false
    t.string "status"
    t.jsonb "payload", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["payload"], name: "index_world_entities_on_payload", using: :gin
    t.index ["world_id", "kind"], name: "index_world_entities_on_world_id_and_kind"
    t.index ["world_id", "label"], name: "index_world_entities_on_world_id_and_label"
    t.index ["world_id", "position"], name: "index_world_entities_on_world_id_and_position"
    t.index ["world_id", "status"], name: "index_world_entities_on_world_id_and_status"
    t.index ["world_id"], name: "index_world_entities_on_world_id"
  end

  add_foreign_key "world_claims", "world_documents", column: "world_id", on_delete: :cascade
  add_foreign_key "world_entities", "world_documents", column: "world_id", on_delete: :cascade
end
