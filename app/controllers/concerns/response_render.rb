module ResponseRender
  extend ActiveSupport::Concern

  def response_400(message:, content: nil)
    json_resp = { message: message }
    json_resp[:content] = content if content
    render json: json_resp, status: 400
  end
end
