require 'rails_helper'

RSpec.describe 'health check requests', type: :request do
  context 'health check' do
    it 'returns a JSON with a success message' do
      get health_check_path

      expected = {
        'success' => true,
        'message' => 'You have successfully hit the yaba API!'
      }
      actual = JSON.parse(response.body)

      expect(expected).to eq(actual)
    end
  end
end
