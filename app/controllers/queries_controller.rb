class QueriesController < ApplicationController
  before_action :authenticate_user!

  def create
    transactions = Tag.fetch_transactions_for_tags_with_names(
      tag_names_params, current_user
    )

    if transactions && transactions.present?
      successful_query(transactions)
    else
      failed_query('Invalid query for transactions')
    end
  end

  private

  def tag_names_params
    params.require(:tag_names)
  end

  def successful_query(transactions)
    render json: {
      message: 'Successful transactions query',
      content: transactions.map(&:jsonify)
    }
  end

  def failed_query(message)
    render json: {
      message: message
    }, status: 400
  end
end
