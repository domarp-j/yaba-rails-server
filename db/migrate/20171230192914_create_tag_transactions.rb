class CreateTagTransactions < ActiveRecord::Migration[5.1]
  def change
    create_table :tag_transactions do |t|
      t.belongs_to :transaction_item, index: true
      t.belongs_to :tag, index: true

      t.timestamps
    end
  end
end
