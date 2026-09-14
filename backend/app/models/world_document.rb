class WorldDocument < ApplicationRecord
  has_many :world_entities, foreign_key: :world_id, dependent: :delete_all, inverse_of: :world_document
  has_many :world_claims, foreign_key: :world_id, dependent: :delete_all, inverse_of: :world_document
end
