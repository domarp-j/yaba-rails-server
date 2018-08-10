class Tag < ApplicationRecord
  has_many :tag_transactions
  has_many :transaction_items, through: :tag_transactions

  belongs_to :user

  validates :name, length: { minimum: 1 }

  def jsonify
    {
      id: id,
      name: name
    }
  end

  def attach_to_transaction_with_id(transaction_id)
    return self if invalid?

    trans = TransactionItem.find_by(id: transaction_id)
    return self unless trans

    TagTransaction.create(
      transaction_item_id: transaction_id,
      tag_id: id
    )

    self
  end

  def attached_to_transaction?(transaction_id)
    TagTransaction.find_by(
      transaction_item_id: transaction_id,
      tag_id: id
    )
  end

  class << self
    def find_or_create_tag_for(user, params)
      existing_tag = user.tags.where(
        'lower(name) = ?',
        params[:name].downcase
      ).first
      return existing_tag if existing_tag

      user.tags.create(
        name: params[:name]
      )
    end
  end
end
