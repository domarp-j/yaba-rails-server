class TransactionItemsController < ApplicationController
  before_action :authenticate_user!

  def index
    result = TransactionItem.fetch_transactions_for(
      current_user,
      limit: limit_param,
      page: page_param,
      tag_names: fetch_params[:tag_names]
    )

    if successful_fetch?(result)
      successful_fetch_response(result)
    else
      failed_fetch_response
    end
  end

  def create
    new_trans = TransactionItem.build_transaction_for(
      current_user, trans_params
    )

    new_trans.save ? successful_create(new_trans) : failed_create(new_trans)
  end

  def update
    trans = TransactionItem.update_transaction_for(current_user, trans_params)
    trans && trans.save ? successful_update(trans) : failed_update
  end

  def destroy
    trans = current_user.transaction_items.find_by(id: trans_params[:id])
    return failed_destroy unless trans
    trans_json = trans.jsonify
    trans.destroy_with_tags!
    successful_destroy(trans_json)
  end

  private

  def fetch_params
    params.permit(:limit, :page, tag_names: [])
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
    render json: {
      message: 'Transactions successfully fetched',
      content: {
        count: result[:count],
        total_amount: result[:total_amount],
        transactions: result[:transactions].map(&:jsonify)
      }
    }, status: 200
  end

  def failed_fetch_response
    render json: {
      message: 'Could not fetch transactions'
    }, status: 400
  end

  def successful_create(transaction)
    render json: {
      message: 'Transaction successfully created',
      content: transaction.jsonify
    }, status: 200
  end

  def failed_create(transaction)
    render json: {
      message: 'Could not create transaction',
      content: transaction.errors.full_messages
    }, status: 400
  end

  def successful_update(transaction)
    render json: {
      message: 'Transaction successfully updated',
      content: transaction.jsonify
    }, status: 200
  end

  def failed_update
    render json: {
      message: 'Could not update transaction'
    }, status: 400
  end

  def successful_destroy(transaction_json)
    render json: {
      message: 'Transaction successfully deleted',
      content: transaction_json
    }, status: 200
  end

  def failed_destroy
    render json: {
      message: 'Could not delete transaction'
    }, status: 400
  end
end
