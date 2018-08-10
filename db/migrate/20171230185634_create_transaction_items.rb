class CreateTransactionItems < ActiveRecord::Migration[5.1]
  def change
    create_table :transaction_items do |t|
      t.text :description, null: false
      t.float :value, null: false
      t.datetime :date, null: false

      t.timestamps
    end
  end
end
