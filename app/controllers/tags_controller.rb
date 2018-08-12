class TagsController < ApplicationController
  before_action :authenticate_user!

  def create
    tag = Tag.find_or_create_tag_for(current_user, tag_params)
             .attach_to_transaction_with_id(tag_params[:transaction_id])

    if tag.valid? && attached_to_transaction?(tag, tag_params[:transaction_id])
      successful_create(tag)
    else
      failed_create(tag)
    end
  end

  def destroy; end

  private

  def tag_params
    params.permit(:id, :name, :transaction_id)
  end

  def attached_to_transaction?(tag, transaction_id)
    return true unless params[:transaction_id]
    tag.attached_to_transaction?(transaction_id)
  end

  def successful_create(tag)
    tag_json = tag.jsonify
    if params[:transaction_id]
      tag_json[:transaction_id] = params[:transaction_id].to_i
    end

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
end
