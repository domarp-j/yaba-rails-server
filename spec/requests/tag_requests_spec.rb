require 'rails_helper'

RSpec.describe 'tag requests:', type: :request do
  let(:user) { create(:user, email: 'test1@example.com') }
  let(:trans) { create(:transaction_item, user: user) }

  before do
    sign_in user
  end

  context 'adding a new tag for a signed-in user' do
    let(:new_tag_name) { 'atm' }
    let(:existing_tag) { create(:tag, name: 'income', user: user) }

    it 'succeeds in creating a new tag' do
      post add_tag_path,
           params: { name: new_tag_name },
           headers: devise_request_headers

      added_tag = Tag.find_by(
        name: new_tag_name
      )

      response_body = JSON.parse(response.body)
      message = response_body['message']
      content = response_body['content']

      expect(response.success?).to be(true)
      expect(message).to eq('Tag successfully saved')
      expect(content['id']).to eq(added_tag.id)
      expect(content['name']).to eq(new_tag_name)
    end

    it 'returns existing tag if it has the provided name' do
      post add_tag_path,
           params: { name: existing_tag.name },
           headers: devise_request_headers

      response_body = JSON.parse(response.body)
      message = response_body['message']
      content = response_body['content']

      expect(response.success?).to be(true)
      expect(message).to eq('Tag successfully saved')
      expect(content['id']).to eq(existing_tag.id)
      expect(content['name']).to eq(existing_tag.name)
    end

    it 'returns a failure for an invalid name' do
      post add_tag_path,
           params: { name: '' },
           headers: devise_request_headers

      response_body = JSON.parse(response.body)
      message = response_body['message']
      content = response_body['content']

      expect(response.success?).to be(false)
      expect(message).to eq('Could not create tag')
      expect(content[0]).to match(/Name is too short/)
    end

    it 'attaches a newly-created tag to a transaction, if the transaction ID is provided' do
      post add_tag_path,
           params: { name: new_tag_name, transaction_id: trans.id },
           headers: devise_request_headers

      added_tag = Tag.find_by(
        name: new_tag_name
      )

      response_body = JSON.parse(response.body)
      message = response_body['message']
      content = response_body['content']

      expect(response.success?).to be(true)
      expect(message).to eq('Tag successfully saved')
      expect(content['id']).to eq(added_tag.id)
      expect(content['name']).to eq(new_tag_name)
      expect(content['transaction_id']).to eq(trans.id)
      expect(trans.tags.find_by(id: added_tag.id)).to eq(added_tag)
      expect(added_tag.transaction_items.find_by(id: trans.id)).to eq(trans)
    end

    it 'attaches an existing tag to a transaction, if the transaction ID is provided' do
      post add_tag_path,
           params: { name: existing_tag.name, transaction_id: trans.id },
           headers: devise_request_headers

      response_body = JSON.parse(response.body)
      message = response_body['message']
      content = response_body['content']

      expect(response.success?).to be(true)
      expect(message).to eq('Tag successfully saved')
      expect(content['id']).to eq(existing_tag.id)
      expect(content['name']).to eq(existing_tag.name)
      expect(content['transaction_id']).to eq(trans.id)
      expect(trans.tags.find_by(id: existing_tag.id)).to eq(existing_tag)
      expect(existing_tag.transaction_items.find_by(id: trans.id)).to eq(trans)
    end

    it 'returns a failure if the transaction with the given ID is not found' do
      post add_tag_path,
           params: { name: new_tag_name, transaction_id: trans.id + 1 },
           headers: devise_request_headers

      response_body = JSON.parse(response.body)
      message = response_body['message']
      content = response_body['content']

      expect(response.success?).to be(false)
      expect(message).to eq('Could not create tag')
      expect(content[0]).to match(/Could not find transaction item/)
    end
  end
end
