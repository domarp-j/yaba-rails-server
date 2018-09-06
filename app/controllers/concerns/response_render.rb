module ResponseRender
  extend ActiveSupport::Concern

  def json_response(message:, status:, content: nil)
    json_resp = { message: message }
    json_resp[:content] = content if content
    render json: json_resp, status: status
  end
end
