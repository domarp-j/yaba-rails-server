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

  def remove_from_transaction_with_id(transaction_id)
    tag_transaction = TagTransaction.find_by(
      transaction_item_id: transaction_id,
      tag_id: id
    )

    tag_transaction.destroy! if tag_transaction
    destroy! if transaction_items.empty?

    self
  end

  def update_for_transaction_with_id(trans_id, user, params)
    transaction = user.transaction_items.find_by(id: trans_id)
    return unless transaction

    # If the current tag is used for multiple transactions,
    # then it is best to play it safe and create a brand new tag with a new name
    if transaction_items.length > 1
      remove_from_transaction_with_id(trans_id)
      Tag.create_tag_for(user, params).attach_to_transaction_with_id(trans_id)
    # If the current tag is only used for one transaction (with ID equal to trans_id),
    # then it's safe to update the name of that tag without updating tags for other transactions
    else
      update(name: params[:name])
      save!
      self
    end
  end

  class << self
    def find_tag_for(user, params)
      if params[:id]
        user.tags.find_by(id: params[:id])
      else
        user.tags.where('lower(name) = ?', params[:name].downcase).first
      end
    end

    def create_tag_for(user, params)
      user.tags.create(name: params[:name])
    end

    def find_or_create_tag_for(user, params)
      existing_tag = find_tag_for(user, params)
      return existing_tag if existing_tag

      create_tag_for(user, params)
    end
  end
end
