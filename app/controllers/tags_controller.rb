class TagsController < ApplicationController
  include ResponseRender

  before_action :authenticate_user!

  # GET index
  # Fetch all of the user's tags
  def index
    json_response(
      message: 'Tags successfully fetched',
      status: 200,
      content: current_user.tags.map do |tag|
        { id: tag.id, name: tag.name }
      end
    )
  end
end
