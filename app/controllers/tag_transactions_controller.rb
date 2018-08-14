class TagTransactionsController < ApplicationController
  before_action :authenticate_user!
  # TODO: Render a 404 response is transaction ID is not given as param

  def create
    tag = Tag.find_or_create_tag_for(current_user, tag_params)
             .attach_to_transaction_with_id(trans_id)

    if tag.valid? && attached_to_transaction?(tag, trans_id)
      successful_create(tag)
    else
      failed_create(tag)
    end
  end

  def update
    tag = Tag.find_tag_for(current_user, tag_params)

    if tag && tag.attached_to_transaction?(trans_id)
      tag.update_for_transaction_with_id(trans_id, current_user, tag_params)
      successful_update(tag)
    else
      failed_update
    end
  end

  def destroy
    tag = Tag.find_tag_for(current_user, tag_params)

    if tag && tag.attached_to_transaction?(trans_id)
      tag.remove_from_transaction_with_id(trans_id)
      successful_destroy(tag)
    else
      failed_destroy
    end
  end

  private

  def tag_params
    params.permit(:id, :name, :new_name, :transaction_id)
  end

  def trans_id
    tag_params[:transaction_id]
  end

  def attached_to_transaction?(tag, transaction_id)
    return true unless params[:transaction_id]
    tag.attached_to_transaction?(transaction_id)
  end

  def tag_json(tag)
    tag_json = tag.jsonify
    tag_json[:transaction_id] = trans_id.to_i
    tag_json
  end

  def successful_create(tag)
    render json: {
      message: 'Tag successfully saved',
      content: tag_json(tag)
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

  def successful_update(tag)
    render json: {
      message: 'Tag successfully updated',
      content: tag_json(tag)
    }, status: 200
  end

  def failed_update
    render json: {
      message: 'Could not update tag'
    }, status: 400
  end

  def successful_destroy(tag)
    render json: {
      message: 'Tag successfully deleted from transaction',
      content: tag_json(tag)
    }, status: 200
  end

  def failed_destroy
    render json: {
      message: 'Could not delete tag from transaction'
    }, status: 400
  end
end
