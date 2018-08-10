class AddUserToTransactionItemsAndTags < ActiveRecord::Migration[5.1]
  def change
    add_reference :transaction_items, :user, foreign_key: true
    add_reference :tags, :user, foreign_key: true
  end
end
