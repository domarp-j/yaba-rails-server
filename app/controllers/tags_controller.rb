class TagsController < ApplicationController
  include ResponseRender

  before_action :authenticate_user!

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
