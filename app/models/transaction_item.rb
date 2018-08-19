class TransactionItem < ApplicationRecord
  has_many :tag_transactions
  has_many :tags, through: :tag_transactions

  belongs_to :user

  DEFAULT_LIMIT = 20
  FIRST_PAGE = 0

  def jsonify
    {
      id: id,
      description: description,
      value: value,
      date: date,
      tags: tags.map(&:jsonify).sort_by { |tag| tag[:name] }
    }
  end

  def attached_to_tag_with_name?(tag_name)
    tags.find_by(name: tag_name).present?
  end

  def destroy_with_tags!
    tags.each do |tag|
      tag.destroy! if tag.transaction_items.length == 1
    end

    destroy!
  end

  def self.fetch_transactions_for(user, limit: DEFAULT_LIMIT, page: FIRST_PAGE)
    includes(:tags, :tag_transactions)
      .where(user_id: user.id)
      .order(date: :desc)
      .limit(limit)
      .offset(limit * page)
  end

  def self.build_transaction_for(user, params)
    user.transaction_items.build(
      description: params[:description],
      value: params[:value].to_f,
      date: Time.parse(params[:date])
    )
  end

  def self.update_transaction_for(user, params)
    trans = user.transaction_items.find_by(id: params[:id])
    return unless trans
    trans.update(description: params[:description]) if params[:description]
    trans.update(value: params[:value].to_f) if params[:value]
    if params[:date]
      trans.update(
        date: Time.parse(params[:date])
      )
    end
    trans
  end
end
