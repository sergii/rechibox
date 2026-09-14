require "test_helper"

class ApiWorldQueryTest < ActionDispatch::IntegrationTest
  test "query endpoint returns direct contents without model inference" do
    world = WorldState::Store.default.create
    box_id = SecureRandom.uuid
    item_id = SecureRandom.uuid

    WorldState::Store.default.update(id: world.fetch("id")) do |state|
      state.fetch("entities").concat([
        entity(box_id, "container", "box"),
        entity(item_id, "item", "cables")
      ])
      state.fetch("claims") << claim("contains", box_id, item_id)
    end

    post "/api/worlds/#{world.fetch("id")}/query",
         params: { intent: "what_is_in", entity_id: box_id },
         as: :json

    assert_response :success
    assert_equal "what_is_in", response.parsed_body.fetch("intent")
    assert_equal [item_id], response.parsed_body.dig("result", "entity_ids")
  end

  test "unsupported query intent is unprocessable" do
    world = WorldState::Store.default.create
    entity_id = SecureRandom.uuid

    WorldState::Store.default.update(id: world.fetch("id")) do |state|
      state.fetch("entities") << entity(entity_id, "item", "item")
    end

    post "/api/worlds/#{world.fetch("id")}/query",
         params: { intent: "invent_answer", entity_id: entity_id },
         as: :json

    assert_response :unprocessable_entity
  end

  private

  def entity(id, kind, label)
    {
      "id" => id,
      "kind" => kind,
      "label" => label,
      "aliases" => [],
      "attributes" => {}
    }
  end

  def claim(predicate, subject_id, object_id)
    {
      "id" => SecureRandom.uuid,
      "predicate" => predicate,
      "subject_id" => subject_id,
      "object" => { "type" => "entity", "id" => object_id },
      "status" => "active",
      "source" => "user",
      "confidence" => 1.0
    }
  end
end
