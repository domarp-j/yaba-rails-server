class TagTransactionsController < ApplicationController
  # TODO: Render a 404 response is transaction ID is not given as param

  include ResponseRender

  before_action :authenticate_user!

  def create
    if transaction_has_tag_with_given_name?
      return response_400(message: 'Transaction already has tag')
    end

    tag = Tag.find_or_create_for(current_user, tag_params)
             .attach_to_transaction_with_id(trans_id)

    if tag.valid? && tag.attached_to_transaction?(trans_id)
      successful_create(tag)
    else
      response_400(message: 'Could not create tag')
    end
  end

  def update
    tag = Tag.find_for(current_user, tag_params)
    return response_400(message: 'Could not find tag to update') unless tag

    new_or_updated_tag = tag.create_or_update_for_transaction_with_id(
      trans_id,
      current_user,
      tag_params
    )

    if new_or_updated_tag
      successful_update(new_or_updated_tag)
    else
      response_400(message: 'Failed to update tag')
    end
  end

  def destroy
    tag = Tag.find_for(current_user, tag_params)

    if tag && tag.attached_to_transaction?(trans_id)
      tag.remove_from_transaction_with_id(trans_id)
      successful_destroy(tag)
    else
      response_400(message: 'Could not delete tag from transaction')
    end
  end

  private

  def tag_params
    params.permit(:id, :name, :transaction_id)
  end

  def trans_id
    tag_params[:transaction_id]
  end

  def transaction_has_tag_with_given_name?
    trans = current_user.transaction_items.find_by(id: trans_id)
    trans && trans.attached_to_tag_with_name?(tag_params[:name])
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

  def successful_update(tag)
    render json: {
      message: 'Tag successfully updated for transaction',
      content: tag_json(tag)
    }, status: 200
  end

  def successful_destroy(tag)
    render json: {
      message: 'Tag successfully deleted from transaction',
      content: tag_json(tag)
    }, status: 200
  end
end
