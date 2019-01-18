class TransactionItemsController < ApplicationController
  include ResponseRender

  before_action :authenticate_user!

  SORT_ATTRIBUTE_PARAMS = %w[description value date].freeze
  SORT_ORDER_PARAMS = %w[asc desc].freeze

  # GET index
  # Fetch all of the user's transactions
  # Fetch query is customized based on provided params (see fetch_params)
  def index
    invalid_params = check_for_invalid_params
    if invalid_params.present?
      return failed_fetch_response(content: invalid_params)
    end

    result = TransactionItem.fetch_transactions_for(
      current_user,
      index_query_params
    )

    if successful_fetch?(result)
      successful_fetch_response(result)
    else
      failed_fetch_response
    end
  end

  # POST create
  # Create a new transaction
  def create
    new_trans = TransactionItem.build_transaction_for(
      current_user, trans_params
    )

    if new_trans.save
      json_response(
        message: 'Transaction successfully created', status: 200,
        content: new_trans.jsonify
      )
    else
      json_response(
        message: 'Could not create transaction', status: 400,
        content: new_trans.errors.full_messages
      )
    end
  end

  # POST update
  # Update an existing transaction
  def update
    trans = TransactionItem.update_transaction_for(current_user, trans_params)

    if trans && trans.save
      json_response(
        message: 'Transaction successfully updated',
        content: trans.jsonify,
        status: 200
      )
    else
      json_response(
        message: trans ? 'Transaction not updated' : 'Transaction not found',
        content: trans ? trans.errors.full_messages : nil,
        status: trans ? 400 : 404
      )
    end
  end

  # POST destroy
  # Delete transaction
  def destroy
    trans = current_user.transaction_items.find_by(id: trans_params[:id])
    unless trans
      return json_response(message: 'Transaction not found', status: 404)
    end
    trans_json = trans.jsonify
    trans.destroy_with_tags!
    json_response(
      message: 'Transaction successfully deleted', status: 200,
      content: trans_json
    )
  end

  private

  def fetch_params
    params.permit(
      :limit, :page,
      :from_date, :to_date,
      :description,
      :match_all_tags,
      :sort_attribute, :sort_order,
      tag_names: []
    )
  end

  def trans_params
    params.permit(:id, :description, :value, :date)
  end

  def fetch_param(param)
    fetch_params[param].present? && fetch_params[param]
  end

  def match_all_tags_param
    return true unless fetch_params[:match_all_tags]
    ActiveRecord::Type::Boolean.new.cast(fetch_params[:match_all_tags])
  end

  def check_for_invalid_params
    errors = []

    sort_attr = fetch_param(:sort_attribute)
    if sort_attr && !SORT_ATTRIBUTE_PARAMS.include?(sort_attr)
      errors << "Invalid sort attribute. Should be one of: #{SORT_ATTRIBUTE_PARAMS}"
    end

    sort_order = fetch_param(:sort_order)
    if sort_order && !SORT_ORDER_PARAMS.include?(sort_order)
      errors << "Invalid sort order. Should be one of: #{SORT_ORDER_PARAMS}"
    end

    errors
  end

  def index_query_params
    index_query = {
      tag_names: fetch_param(:tag_names),
      from_date: fetch_param(:from_date),
      to_date: fetch_param(:to_date),
      description: fetch_param(:description),
      sort_attribute: fetch_param(:sort_attribute),
      sort_order: fetch_param(:sort_order)
    }

    index_query[:limit] = fetch_param(:limit).to_i if fetch_param(:limit)
    index_query[:page] = fetch_param(:page).to_i if fetch_param(:page)
    index_query[:match_all_tags] = match_all_tags_param

    index_query
  end

  def successful_fetch?(result)
    result[:count] > 0 || (fetch_param(:page) && fetch_param(:page).to_i > 0)
  end

  def successful_fetch_response(result)
    json_response(
      message: 'Transactions successfully fetched', status: 200,
      content: {
        count: result[:count],
        total_amount: result[:total_amount],
        transactions: result[:transactions].map(&:jsonify)
      }
    )
  end

  def failed_fetch_response(content: nil)
    json_response(
      message: 'Could not fetch transactions', status: 400,
      content: content
    )
  end
end
