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
      tags: tags.map(&:jsonify)
                .sort_by { |tag| tag[:name] }
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
      tag_names: [],
      from_date: nil,
      to_date: nil,
      description: nil
    )
      transactions = all_transactions_for(
        user,
        tag_names: tag_names,
        from_date: from_date, to_date: to_date,
        description: description
      )

      {
        count: transactions.count,
        total_amount: calculate_sum(transactions),
        transactions: transactions.order(date: :desc, created_at: :desc)
                                  .limit(limit)
                                  .offset(limit * page)
      }
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
      trans.update(date: Time.parse(params[:date])) if params[:date]
      trans
    end

    private

    # Using TransactionItem.includes adds several duplicate transactions that changes the sum.
    # This method removes those duplicates & gets the sum for a list of *unique* transactions.
    def calculate_sum(transactions)
      where(id: transactions.pluck(:id).uniq).sum(:value).round(2)
    end

    def all_transactions_for(
      user,
      tag_names:,
      from_date:,
      to_date:,
      description:
    )
      includes(:tag_transactions, :tags)
        .where(
          search_by_active_record(
            user: user,
            tag_names: tag_names,
            from_date: from_date,
            to_date: to_date
          )
        )
        .where(
          search_by_sql(
            description: description
          )
        )
    end

    # Search transactions using ActiveRecord
    def search_by_active_record(user:, tag_names:, from_date:, to_date:)
      query = { user_id: user.id }

      # Query by tag name
      if tag_names.present?
        tag_ids = Tag.ids_for_names(tag_names, user)
        return no_transactions_query unless tag_names.length == tag_ids.length
        trans_ids = transactions_with_tag_ids(tag_ids)
        query[:id] = trans_ids
      end

      # Query by date range
      query_from_date = from_date || Time.parse('1970-01-01')
      query_to_date = to_date || Time.now
      query[:date] = query_from_date..query_to_date

      query
    end

    # Search transactions using reliable old SQL
    def search_by_sql(description:)
      # Check for partial match of provided description
      return unless description
      ['lower(description) like ?', "%#{description}%"]
    end

    # This method return IDs for t    ransactions that are attached to tags with
    # the provided IDs.
    # It ensures that the returned transaction are attached to *all* of the
    # provided tags rather than *any* tag.
    def transactions_with_tag_ids(tag_ids)
      # Get all of the tag-transactions associated with the provided tag_ids
      # Crucial: Sort by transaction item ID, *then* by tag ID for the next step
      tag_transactions = TagTransaction.where(tag_id: tag_ids)
                                       .order(
                                         transaction_item_id: :asc, tag_id: :asc
                                       )

      # Keep a running list of transaction IDs
      transaction_ids = []

      # Iterate through the sorted tag-transactions in batches
      tag_transactions.each_cons(tag_ids.count) do |tag_trans_batch|
        # Check if the current batch of tag-transactions has the same order of
        # tag IDs as a sorted version of the provided tag_ids. Proceed to next
        # iteration if that is not the case.
        next unless tag_trans_batch.map(&:tag_id) == tag_ids.sort

        # After the previous check, it is more than likely that a transaction
        # has been found with all of the required tags. However, we can double
        # check by making sure the current batch of tag-transactions is all
        # related to the same transaction.
        batch_trans_ids = tag_trans_batch.map(&:transaction_item_id)
        next unless batch_trans_ids.uniq.length == 1

        # By this point, we can be sure that we found a transaction with the
        # required tags. Add it to the list & proceed.
        transaction_ids << batch_trans_ids.first
      end

      transaction_ids
    end

    # TODO: Improve how to return 0 transactions if all tag names
    # do not map to tags
    def no_transactions_query
      { created_at: Time.now + 50.years }
    end
  end
end
