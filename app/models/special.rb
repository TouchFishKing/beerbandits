class Special < ApplicationRecord
  belongs_to :store
  monetize :price_cents
end
