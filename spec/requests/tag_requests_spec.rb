require 'rails_helper'

RSpec.describe 'tag requests:', type: :request do
  let(:user) { create(:user, email: 'test1@example.com') }
  let(:trans) { create(:transaction_item, user: user) }

  before do
    sign_in user
  end

  context 'fetching all tags' do
    it "returns a list of all of the user's tags" do
      tags = [
        create(:tag, name: 'tag0', user: user),
        create(:tag, name: 'tag1', user: user),
        create(:tag, name: 'tag2', user: user),
        create(:tag, name: 'tag3', user: user),
        create(:tag, name: 'tag4', user: user)
      ]

      get tags_path, headers: devise_request_headers

      assert_response_success(expected_message: 'Tags successfully fetched')
      expect(content.length).to eq(tags.length)
      tags.each do |tag|
        expect(content).to include('id' => tag.id, 'name' => tag.name)
      end
    end

    it 'returns an empty array but a success status if the user has no tags' do
      get tags_path, headers: devise_request_headers

      assert_response_success(expected_message: 'Tags successfully fetched')
      expect(content).to eq([])
    end
  end
end
