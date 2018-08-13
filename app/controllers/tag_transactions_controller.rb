class TagTransactionsController < ApplicationController
  before_action :authenticate_user!

  def create
    tag = Tag.find_or_create_tag_for(current_user, tag_params)
             .attach_to_transaction_with_id(trans_id)

    if tag.valid? && attached_to_transaction?(tag, trans_id)
      successful_create(tag)
    else
      failed_create(tag)
    end
  end

  def destroy
    tag = Tag.find_tag_for(current_user, tag_params)

    if tag && tag.attached_to_transaction?(trans_id)
      tag.remove_transaction_with_id(trans_id)
      successful_destroy(tag)
    else
      failed_destroy
    end
  end

  private

  def tag_params
    params.permit(:id, :name, :transaction_id)
  end

  def trans_id
    tag_params[:transaction_id]
  end

  def attached_to_transaction?(tag, transaction_id)
    return true unless params[:transaction_id]
    tag.attached_to_transaction?(transaction_id)
  end

  def successful_create(tag)
    tag_json = tag.jsonify
    tag_json[:transaction_id] = params[:transaction_id].to_i

    render json: {
      message: 'Tag successfully saved',
      content: tag_json
    }, status: 200
  end

  def failed_create(tag)
    errors = tag.errors.full_messages
    errors << 'Could not find transaction item' if params[:transaction_id]

    render json: {
      message: 'Could not create tag',
      content: errors
    }, status: 400
  end

  def successful_destroy(tag)
    tag_json = tag.jsonify
    tag_json[:transaction_id] = params[:transaction_id].to_i

    render json: {
      message: 'Tag successfully deleted from transaction',
      content: tag_json
    }, status: 200
  end

  def failed_destroy
    render json: {
      message: 'Could not delete tag from transaction'
    }, status: 400
  end
end
