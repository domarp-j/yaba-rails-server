class TagTransaction < ApplicationRecord
  belongs_to :transaction_item
  belongs_to :tag
end
