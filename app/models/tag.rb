class Tag < ApplicationRecord
  # TODO: Remove use of params throughout

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

  def attached_to_transaction?(transaction_id)
    TagTransaction.find_by(
      transaction_item_id: transaction_id,
      tag_id: id
    )
  end

  def attach_to_transaction_with_id(transaction_id)
    return self if invalid?

    trans = TransactionItem.find_by(id: transaction_id)
    return self unless trans

    TagTransaction.find_or_create_by(
      tag_id: id,
      transaction_item_id: transaction_id
    )

    self
  end

  def remove_from_transaction_with_id(trans_id)
    tag_transaction = TagTransaction.find_by(
      transaction_item_id: trans_id,
      tag_id: id
    )

    # Remove tag-transaction relationship
    tag_transaction.destroy! if tag_transaction

    # Destroy self if no longer associated with any transactions
    destroy! if transaction_items.empty?

    self
  end

  def create_or_update_for_transaction_with_id(trans_id, user, params)
    transaction = user.transaction_items.find_by(id: trans_id)
    return unless transaction

    handle_create_update_for(user, trans_id, params)
  end

  def self.find_for(user, params)
    if params[:id]
      user.tags.find_by(id: params[:id])
    else
      Tag.find_by_names_for_user(user, params[:name]).first
    end
  end

  def self.create_for(user, params)
    user.tags.create(name: params[:name])
  end

  def self.find_or_create_for(user, params)
    existing_tag = find_for(user, params)
    return existing_tag if existing_tag

    create_for(user, params)
  end

  def self.find_by_names_for_user(user, name)
    user.tags.where('lower(name) = ?', name.downcase)
  end

  def self.get_transaction_ids_for_tags_with_names(tag_names, user)
    tag_ids = user.tags
                  .where(name: tag_names)
                  .select(:id)

    TagTransaction.where(tag_id: tag_ids)
                  .pluck(:transaction_item_id)
  end

  private

  def handle_create_update_for(user, trans_id, params)
    # Check if user already has a tag with the new name
    tag_with_new_name = Tag.find_for(user, name: params[:name])

    # If the user already has a tag with the new name
    # then delete the current tag's relationship with the transaction with id "trans_id"
    # and associate the new tag with that same transaction
    if tag_with_new_name
      remove_from_transaction_with_id(trans_id)
      tag_with_new_name.attach_to_transaction_with_id(trans_id)

    # If the user does not have a tag with the new name
    # and the current tag is associated with multiple transactions
    # then create a new tag with the new name
    # and associate it with the provided transaction
    # and delete the older tag's relationship with the provided transaction
    elsif transaction_items.length > 1
      remove_from_transaction_with_id(trans_id)
      Tag.create_for(user, params).attach_to_transaction_with_id(trans_id)

    # If the user does not have a tag with the new name
    # and the current tag is only associated with the provided transaction
    # then simply update the name of the current tag
    else
      update_with_params(params)
    end
  end

  def update_with_params(params)
    update(name: params[:name])
    save!
    self
  end
end
