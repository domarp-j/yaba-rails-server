require 'rails_helper'

RSpec.describe 'tag-transaction requests:', type: :request do
  let(:user) { create(:user, email: 'test1@example.com') }
  let(:trans) { create(:transaction_item, user: user) }

  before do
    sign_in user
  end

  context 'adding a new tag to a transaction' do
    let(:new_tag_name) { 'atm' }
    let(:existing_tag) { create(:tag, name: 'income', user: user) }

    it 'attaches a brand-new tag to a transaction' do
      post add_tag_transaction_path(transaction_id: trans.id),
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
      expect(content['transaction_id']).to eq(trans.id)
      expect(trans.tags.find_by(id: added_tag.id)).to eq(added_tag)
      expect(added_tag.transaction_items.find_by(id: trans.id)).to eq(trans)
    end

    it 'attaches an existing tag to a transaction, if the transaction ID is provided' do
      post add_tag_transaction_path(transaction_id: trans.id),
           params: { name: existing_tag.name },
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
      post add_tag_transaction_path(transaction_id: trans.id + 1),
           params: { name: new_tag_name },
           headers: devise_request_headers

      response_body = JSON.parse(response.body)
      message = response_body['message']
      # content = response_body['content']

      expect(response.success?).to be(false)
      expect(message).to eq('Could not create tag')
      # expect(content[0]).to match(/Could not find transaction item/)
    end

    it 'returns a failure for an invalid name' do
      post add_tag_transaction_path(transaction_id: trans.id),
           params: { name: '' },
           headers: devise_request_headers

      response_body = JSON.parse(response.body)
      message = response_body['message']
      # content = response_body['content']

      expect(response.success?).to be(false)
      expect(message).to eq('Could not create tag')
      # expect(content[0]).to match(/Name is too short/)
    end

    it 'returns a failure if a tag with the provided name is already attached to the transaction' do
      create(:tag_transaction, tag_id: existing_tag.id, transaction_item_id: trans.id)

      post add_tag_transaction_path(transaction_id: trans.id),
           params: { name: existing_tag.name },
           headers: devise_request_headers

      response_body = JSON.parse(response.body)
      message = response_body['message']
      # content = response_body['content']

      expect(response.success?).to be(false)
      expect(message).to eq('Transaction already has tag')
    end
  end

  context 'updating a tag for a transaction' do
    let(:transaction_id) { 176 }
    let(:tag_id) { 1001 }
    let(:tag_name) { 'atm' }
    let(:new_tag_name) { 'atm-withdrawal' }

    let(:transaction_item) { create(:transaction_item, id: transaction_id, user: user) }
    let(:tag) { create(:tag, id: tag_id, name: tag_name, user: user) }
    let!(:tag_transaction) { create(:tag_transaction, tag: tag, transaction_item: transaction_item) }

    it 'updates the name of the tag' do
      post update_tag_transaction_path(transaction_id: transaction_id),
           params: { id: tag_id, name: new_tag_name },
           headers: devise_request_headers

      response_body = JSON.parse(response.body)
      content = response_body['content']

      expect(response.success?).to be(true)
      expect(response_body['message']).to eq('Tag successfully updated for transaction')
      expect(content['id']).to eq(tag_id)
      expect(content['name']).to eq(new_tag_name)
      expect(content['transaction_id']).to eq(transaction_id)

      updated_tag = Tag.find_by(id: tag_id)
      expect(updated_tag.name).to eq(new_tag_name)
    end

    it 'returns a failure if the transaction is not found' do
      post update_tag_transaction_path(transaction_id: transaction_id + 1),
           params: { id: tag_id, name: new_tag_name },
           headers: devise_request_headers

      response_body = JSON.parse(response.body)

      expect(response.success?).to be(false)
      expect(response_body['message']).to eq('Could not update tag')
    end

    it 'returns a failure if the tag is not found' do
      post update_tag_transaction_path(transaction_id: transaction_id),
           params: { id: tag_id + 1, name: new_tag_name },
           headers: devise_request_headers

      response_body = JSON.parse(response.body)

      expect(response.success?).to be(false)
      expect(response_body['message']).to eq('Could not find tag')
    end
  end

  context 'removing a tag from a transaction' do
    let(:tag_id) { 99 }
    let(:transaction_id) { 67 }
    let(:tag_name) { 'some-tag' }

    let!(:transaction_item) { create(:transaction_item, id: transaction_id, user: user) }
    let!(:tag) { create(:tag, id: tag_id, name: tag_name, user: user) }

    it 'removes the tag from the transaction with a given ID' do
      create(:tag_transaction, tag: tag, transaction_item: transaction_item)

      expect(tag.transaction_items.find_by(id: transaction_id)).to eq(transaction_item)
      expect(transaction_item.tags.find_by(id: tag_id)).to eq(tag)

      post destroy_tag_transaction_path(transaction_id: transaction_id),
           params: { name: tag.name },
           headers: devise_request_headers

      response_body = JSON.parse(response.body)
      content = response_body['content']

      expect(response.success?).to be(true)
      expect(response_body['message']).to eq('Tag successfully deleted from transaction')
      expect(content['id']).to eq(tag_id)
      expect(content['name']).to eq(tag_name)
      expect(content['transaction_id']).to eq(transaction_id)
      expect(tag.transaction_items.find_by(id: transaction_id)).to be_nil
      expect(transaction_item.tags.find_by(id: tag_id)).to be_nil
    end

    it 'returns a failure if the tag is not attached to the transaction with the given ID' do
      post destroy_tag_transaction_path(transaction_id: transaction_id),
           params: { name: tag.name },
           headers: devise_request_headers

      response_body = JSON.parse(response.body)

      expect(response.success?).to be(false)
      expect(response_body['message']).to eq('Could not delete tag')
    end
  end
end
