# Module for helpers that will be commonly used in request specs
module RequestHelper
  def body
    JSON.parse(response.body)
  end

  def message
    body['message']
  end

  def content
    body['content']
  end

  def assert_response_success(expected_message:)
    expect(response.success?).to be(true)
    expect(message).to eq(expected_message)
  end

  def assert_response_failure(expected_message:)
    expect(response.success?).to be(false)
    expect(message).to eq(expected_message)
  end
end
