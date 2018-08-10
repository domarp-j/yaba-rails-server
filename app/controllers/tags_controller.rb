class TagsController < ApplicationController
  before_action :authenticate_user!

  def create
    tag = Tag.find_or_create_tag_for(current_user, tag_params)
             .attach_to_transaction_with_id(tag_params[:transaction_id])

    if tag.valid? && tag_attached_to_transaction?(tag, params[:transaction_id])
      successful_create(tag)
    else
      failed_create(tag)
    end
  end

  private

  def tag_params
    params.permit(:name, :transaction_id)
  end

  def tag_attached_to_transaction?(tag, transaction_id)
    return true unless params[:transaction_id]
    tag.attached_to_transaction?(transaction_id)
  end

  def successful_create(tag)
    render json: {
      message: 'Tag successfully saved',
      content: display_content_for(tag)
    }, status: 200
  end

  def failed_create(tag)
    render json: {
      message: 'Could not create tag',
      content: display_errors_for(tag)
    }, status: 400
  end

  def display_content_for(tag)
    tag_json = tag.jsonify
    if params[:transaction_id]
      tag_json[:transaction_id] = params[:transaction_id].to_i
    end
    tag_json
  end

  def display_errors_for(tag)
    errors = tag.errors.full_messages
    errors << 'Could not find transaction item' if params[:transaction_id]
    errors
  end
end
