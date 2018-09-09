class TransactionItemsController < ApplicationController
  include ResponseRender

  before_action :authenticate_user!

  def index
    result = TransactionItem.fetch_transactions_for(
      current_user,
      index_query_params
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
    params.permit(
      :limit, :page,
      :from_date, :to_date,
      :description,
      tag_names: []
    )
  end

  def trans_params
    params.permit(:id, :description, :value, :date)
  end

  def param_for(param)
    fetch_params[param].present? && fetch_params[param]
  end

  def index_query_params
    index_query = {
      tag_names: param_for(:tag_names),
      from_date: param_for(:from_date),
      to_date: param_for(:to_date),
      description: param_for(:description)
    }

    index_query[:limit] = param_for(:limit).to_i if param_for(:limit)
    index_query[:page] = param_for(:page).to_i if param_for(:page)

    index_query
  end

  def successful_fetch?(result)
    result[:count] > 0 || (param_for(:page) && param_for(:page) > 0)
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
