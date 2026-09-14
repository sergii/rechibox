require "test_helper"

class ActiveRecordPersistenceTest < ActiveSupport::TestCase
  setup do
    @previous_adapter = ENV["PERSISTENCE_ADAPTER"]
    ENV["PERSISTENCE_ADAPTER"] = "active_record"
  end

  teardown do
    ENV["PERSISTENCE_ADAPTER"] = @previous_adapter
  end

  test "default stores use Active Record" do
    assert_instance_of WorldState::Stores::ActiveRecord, WorldState::Store.default
    assert_instance_of Conversations::Stores::ActiveRecord, Conversations::Store.default
    assert_instance_of Conversations::TurnStores::ActiveRecord, Conversations::TurnStore.default
    assert_instance_of WorldState::ProposalStores::ActiveRecord, WorldState::ProposalStore.default
    assert_instance_of WorldState::ClarificationStores::ActiveRecord, WorldState::ClarificationStore.default
  end

  test "world updates roll back with the surrounding transaction" do
    store = WorldState::Stores::ActiveRecord.new
    world = store.create

    assert_raises RuntimeError do
      Persistence.transaction do
        store.update(id: world.fetch("id")) do |state|
          state.fetch("entities") << {
            "id" => SecureRandom.uuid,
            "kind" => "container",
            "label" => "temporary box",
            "attributes" => {}
          }
        end
        raise "force rollback"
      end
    end

    assert_empty store.fetch(world.fetch("id")).fetch("entities")
  end

  test "json directory remains an explicit compatibility adapter" do
    ENV["PERSISTENCE_ADAPTER"] = "json_directory"

    assert_instance_of WorldState::Stores::JsonDirectory, WorldState::Store.default
    assert_instance_of Conversations::Stores::JsonDirectory, Conversations::Store.default
  end
end
