require "test_helper"

class WorldStateQueryAnswerRendererTest < ActiveSupport::TestCase
  setup do
    @renderer = WorldState::QueryAnswerRenderer.new
    @item_id = SecureRandom.uuid
    @box_id = SecureRandom.uuid
    @garage_id = SecureRandom.uuid
    @person_id = SecureRandom.uuid
  end

  test "renders a nested physical location with supporting provenance" do
    claim_one = SecureRandom.uuid
    claim_two = SecureRandom.uuid
    answer = @renderer.call(
      message: "Де мої кабелі?",
      query: query("where_is", "кабелі"),
      resolution: resolved,
      query_result: query_result(
        "where_is",
        "ambiguous" => false,
        "paths" => [{
          "entity_ids" => [@item_id, @box_id, @garage_id],
          "entities" => [entity(@item_id, "кабелі"), entity(@box_id, "синя коробка"), entity(@garage_id, "гараж")],
          "edges" => [edge(claim_one), edge(claim_two)],
          "cycle" => false,
          "truncated" => false
        }]
      )
    )

    assert_equal "resolved", answer.fetch("status")
    assert_equal "uk", answer.fetch("locale")
    assert_equal "Розташування «кабелі»: синя коробка → гараж.", answer.fetch("text")
    assert_equal [claim_one, claim_two], answer.fetch("supporting_claim_ids")
  end

  test "renders direct contents without claiming an empty container is known empty" do
    claim_id = SecureRandom.uuid
    answer = @renderer.call(
      message: "What is in the blue box?",
      query: query("what_is_in", "blue box"),
      resolution: resolved,
      query_result: query_result(
        "what_is_in",
        "entities" => [entity(@item_id, "cables")],
        "edges" => [edge(claim_id)]
      )
    )

    assert_equal "resolved", answer.fetch("status")
    assert_equal "Contents of “blue box”: cables.", answer.fetch("text")
    assert_equal [claim_id], answer.fetch("supporting_claim_ids")

    unknown = @renderer.call(
      message: "What is in the blue box?",
      query: query("what_is_in", "blue box"),
      resolution: resolved,
      query_result: query_result("what_is_in", "entities" => [], "edges" => [])
    )
    assert_equal "unknown", unknown.fetch("status")
  end

  test "multiple owners remain a resolved collection" do
    second_person_id = SecureRandom.uuid
    answer = @renderer.call(
      message: "Who owns the drill?",
      query: query("who_owns", "drill"),
      resolution: resolved,
      query_result: query_result(
        "who_owns",
        "ambiguous" => true,
        "entities" => [entity(@person_id, "Alex"), entity(second_person_id, "Sam")],
        "edges" => [edge(SecureRandom.uuid), edge(SecureRandom.uuid)]
      )
    )

    assert_equal "resolved", answer.fetch("status")
    assert_includes answer.fetch("text"), "Alex, Sam"
  end

  test "multiple custody records surface an integrity conflict" do
    answer = @renderer.call(
      message: "Who has the drill?",
      query: query("who_has_custody", "drill"),
      resolution: resolved,
      query_result: query_result(
        "who_has_custody",
        "ambiguous" => true,
        "entities" => [entity(@person_id, "Alex"), entity(SecureRandom.uuid, "Sam")],
        "edges" => [edge(SecureRandom.uuid), edge(SecureRandom.uuid)]
      )
    )

    assert_equal "conflict", answer.fetch("status")
  end

  test "entity ambiguity is rendered as a clarification instead of a guessed answer" do
    answer = @renderer.call(
      message: "Що в синій коробці?",
      query: query("what_is_in", "синя коробка"),
      resolution: { "status" => "ambiguous" },
      query_result: nil
    )

    assert_equal "ambiguous", answer.fetch("status")
    assert_nil answer.fetch("supporting_claim_ids").first
    assert_includes answer.fetch("text"), "Потрібне уточнення"
  end

  test "a location cycle is not presented as a resolved location" do
    claim_id = SecureRandom.uuid
    answer = @renderer.call(
      message: "Where are the cables?",
      query: query("where_is", "cables"),
      resolution: resolved,
      query_result: query_result(
        "where_is",
        "ambiguous" => false,
        "paths" => [{
          "entities" => [entity(@item_id, "cables"), entity(@box_id, "box"), entity(@item_id, "cables")],
          "edges" => [edge(claim_id)],
          "cycle" => true,
          "truncated" => false
        }]
      )
    )

    assert_equal "conflict", answer.fetch("status")
    assert_equal [claim_id], answer.fetch("supporting_claim_ids")
  end

  private

  def query(intent, label)
    { "intent" => intent, "entity" => { "ref" => "E1", "kind" => "other", "label" => label } }
  end

  def resolved
    { "status" => "resolved", "durable_entity_id" => @item_id }
  end

  def query_result(intent, result)
    { "intent" => intent, "entity_id" => @item_id, "result" => result }
  end

  def entity(id, label)
    { "id" => id, "kind" => "other", "label" => label, "attributes" => {} }
  end

  def edge(claim_id)
    { "claim_id" => claim_id }
  end
end
