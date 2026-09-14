class WorldEntity < ApplicationRecord
  belongs_to :world_document, foreign_key: :world_id, inverse_of: :world_entities
end
