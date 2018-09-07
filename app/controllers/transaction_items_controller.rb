class TransactionItemsController < ApplicationController
  include ResponseRender

  before_action :authenticate_user!

  def index
    result = TransactionItem.fetch_transactions_for(
      current_user,
      limit: limit_param,
      page: page_param,
      tag_names: fetch_params[:tag_names],
      from_date: fetch_params[:from_date],
      to_date: fetch_params[:to_date]
    )

    if successful_fetch?(result)
      successful_fetch_response(result)
    else
      json_response(message: 'Could not fetch transactions', status: 400)
    end
  end

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

  def update
    trans = TransactionItem.update_transaction_for(current_user, trans_params)
    if trans && trans.save
      json_response(
        message: 'Transaction successfully updated', status: 200,
        content: trans.jsonify
      )
    else
      json_response(message: 'Could not update transaction', status: 400)
    end
  end

  def destroy
    trans = current_user.transaction_items.find_by(id: trans_params[:id])
    unless trans
      return json_response(message: 'Transaction not found', status: 400)
    end
    trans_json = trans.jsonify
    trans.destroy_with_tags!
    json_response(
      message: 'Transaction deleted', status: 200,
      content: trans_json
    )
  end

  private

  def fetch_params
    params.permit(:limit, :page, :from_date, :to_date, tag_names: [])
  end

  def trans_params
    params.permit(:id, :description, :value, :date)
  end

  def param_for(param_key, fallback:)
    fetch_params[param_key] ? fetch_params[param_key].to_i : fallback
  end

  def limit_param
    param_for(:limit, fallback: TransactionItem::DEFAULT_LIMIT)
  end

  def page_param
    param_for(:page, fallback: TransactionItem::FIRST_PAGE)
  end

  def successful_fetch?(result)
    result[:count] > 0 || page_param > 0
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
end
