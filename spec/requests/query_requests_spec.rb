require 'rails_helper'

RSpec.describe 'query requests:', type: :request do
  let(:user) { create(:user, email: 'test1@example.com') }

  before do
    sign_in user
  end

  context 'queries for transactions' do
    let(:tag_names) { ['first-tag', 'second-tag', 'third-tag', 'fourth-tag'] }

    before do
      tag_names.each do |tag_name|
        tag = create(:tag, name: tag_name, user: user)
        transactions = create_list(:transaction_item, rand(1..3), user: user)
        transactions.each do |trans|
          create(:tag_transaction, tag_id: tag.id, transaction_item_id: trans.id)
        end
      end
    end

    it 'returns a collection of transactions associated with provided tag names' do
      post create_query_path,
           params: { tag_names: tag_names },
           headers: devise_request_headers

      response_body = JSON.parse(response.body)
      message = response_body['message']
      content = response_body['content']

      expect(response.success?).to be(true)
      expect(message).to eq('Successful transactions query')
      expect(content).to be_instance_of(Array)

      transaction_ids = content.map { |trans| trans['id'] }

      tag_names.each do |tag_name|
        tag = user.tags.find_by(name: tag_name)
        tag.transaction_items.each do |trans|
          expect(transaction_ids).to include(trans.id)
        end
      end
    end

    it 'returns a failure if tags are not found with the provided names' do
      post create_query_path,
           params: { tag_names: ['random-tag', 'some-tag'] },
           headers: devise_request_headers

      response_body = JSON.parse(response.body)
      message = response_body['message']

      expect(response.success?).to be(false)
      expect(message).to eq('Invalid query for transactions')
    end
  end
end
