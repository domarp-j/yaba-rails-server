class TransactionItem < ApplicationRecord
  # TODO: Remove use of params throughout

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

  class << self
    def fetch_transactions_for(
      user,
      limit: DEFAULT_LIMIT,
      page: FIRST_PAGE,
      tag_names: []
    )
      includes(:tags, :tag_transactions)
        .where(
          matches_filter_criteria(
            user: user,
            tag_names: tag_names
          )
        )
        .order(date: :desc, created_at: :desc)
        .limit(limit)
        .offset(limit * page)
    end

    def build_transaction_for(user, params)
      user.transaction_items.build(
        description: params[:description],
        value: params[:value].to_f,
        date: Time.parse(params[:date])
      )
    end

    def update_transaction_for(user, params)
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

    def filter_by_tag_names!(tag_names)
      tag_ids = user.tags
                    .where(name: tag_names)
                    .select(:id)

      trans_ids = TagTransaction.where(tag_id: tag_ids)
                                .select(:transaction_item_id)

      where(id: trans_ids)
    end

    private

    def matches_filter_criteria(user:, tag_names:)
      query = { user_id: user.id }

      return query unless tag_names.present?
      trans_ids = Tag.get_transaction_ids_for_tags_with_names(tag_names, user)
      query[:id] = trans_ids

      query
    end
  end
end
