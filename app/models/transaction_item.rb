class TransactionItem < ApplicationRecord
  has_many :tag_transactions
  has_many :tags, through: :tag_transactions

  belongs_to :user

  DEFAULT_LIMIT = 20
  FIRST_PAGE = 0
  DEFAULT_SORT_ATTRIBUTE = :date
  DEFAULT_SORT_ORDER = {
    description: :asc,
    value: :desc,
    date: :desc
  }.freeze

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
      description: nil,
      match_all_tags: true,
      sort_attribute: nil,
      sort_order: nil
    )
      transactions = all_transactions_for(
        user,
        tag_names: tag_names,
        from_date: from_date, to_date: to_date,
        description: description,
        match_all_tags: match_all_tags
      )

      {
        count: transactions.count,
        total_amount: calculate_sum(transactions),
        transactions: transactions.order(sort_query(sort_attribute, sort_order))
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
      description:,
      match_all_tags:
    )
      includes(:tag_transactions, :tags)
        .where(
          search_by_active_record(
            user: user,
            tag_names: tag_names,
            from_date: from_date,
            to_date: to_date,
            match_all_tags: match_all_tags
          )
        )
        .where(
          search_by_sql(
            description: description
          )
        )
    end

    # Search transactions using ActiveRecord
    def search_by_active_record(
      user:,
      tag_names:,
      from_date:,
      to_date:,
      match_all_tags:
    )
      query = { user_id: user.id }

      # Query by tag name
      if tag_names.present?
        tag_ids = Tag.ids_for_names(tag_names, user)

        if match_all_tags
          return no_transactions_query unless tag_names.length == tag_ids.length
          trans_ids = transactions_with_all_tags(tag_ids)
        else
          trans_ids = transactions_with_any_tags(tag_ids)
        end

        query[:id] = trans_ids
      end

      # Query by date range
      query_from_date = from_date || Time.parse('1970-01-01')
      query_to_date = to_date || latest_transaction_date_for(user)
      query[:date] = query_from_date..query_to_date

      query
    end

    # Search transactions using reliable old SQL
    def search_by_sql(description:)
      # Check for partial match of provided description
      return unless description
      ['lower(description) like ?', "%#{description.downcase}%"]
    end

    # Return IDs for transactions that are attached to *all* of the provided tags
    def transactions_with_all_tags(tag_ids)
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

    # Return IDs for transactions that are attached to *any* of the provided tags
    def transactions_with_any_tags(tag_ids)
      tag_transactions = TagTransaction.where(tag_id: tag_ids)
      tag_transactions.pluck(:transaction_item_id).uniq
    end

    # TODO: Improve how to return 0 transactions if all tag names
    # do not map to tags
    def no_transactions_query
      { created_at: Time.now + 50.years }
    end

    # Determine transaction sorting query based on attribute & order
    def sort_query(sort_attribute, sort_order)
      attrib = sort_attribute ? sort_attribute : DEFAULT_SORT_ATTRIBUTE
      order = sort_order || DEFAULT_SORT_ORDER[attrib]

      query = { attrib.to_sym => order }
      query[:created_at] = :desc
      query
    end

    # Return the date for the user's latest transaction
    # Needed to fetch transactions with future dates, particularly when the user
    # does not provide a "to" date as part of the transaction query.
    # Add a padding of 1 year to make sure all transactions are found
    def latest_transaction_date_for(user)
      latest_transaction = user.transaction_items.order(date: :asc).last
      return Time.now unless latest_transaction
      latest_transaction.date + 1.year
    end
  end
end
