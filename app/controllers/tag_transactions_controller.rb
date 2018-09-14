class TagTransactionsController < ApplicationController
  include ResponseRender

  before_action :authenticate_user!

  def create
    if transaction_has_tag_with_given_name?
      return json_response(message: 'Transaction already has tag', status: 400)
    end

    tag = Tag.find_or_create_for(current_user, tag_params)
             .attach_to_transaction_with_id(trans_id)

    if tag.valid? && tag.attached_to_transaction?(trans_id)
      json_response(
        message: 'Tag successfully saved',
        content: tag_json(tag),
        status: 200
      )
    else
      failed_response(tag, message: 'Could not create tag')
    end
  end

  def update
    tag = Tag.find_for(current_user, tag_params)
    return json_response(message: 'Could not find tag', status: 400) unless tag

    new_or_updated_tag = tag.create_or_update_for_transaction_with_id(
      trans_id, current_user, tag_params
    )

    if new_or_updated_tag
      json_response(
        message: 'Tag successfully updated for transaction',
        content: tag_json(new_or_updated_tag),
        status: 200
      )
    else
      failed_response(tag, message: 'Could not update tag')
    end
  end

  def destroy
    tag = Tag.find_for(current_user, tag_params)

    if tag && tag.attached_to_transaction?(trans_id)
      tag.remove_from_transaction_with_id(trans_id)
      json_response(
        message: 'Tag successfully deleted from transaction',
        content: tag_json(tag),
        status: 200
      )
    else
      json_response(message: 'Could not delete tag', status: 400)
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

  def failed_response(tag, message:)
    json_response(
      message: message,
      content: tag.errors.full_messages,
      status: 400
    )
  end
end
