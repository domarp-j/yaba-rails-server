require 'rails_helper'

RSpec.describe Tag, type: :model do
  let(:user) { create(:user) }

  describe '#jsonify' do
    let(:test_name) { 'atm' }

    let(:tag) { create(:tag, name: test_name, user: user) }
    let(:jsonified_tag) { tag.jsonify }

    it 'returns a JSON with a name field' do
      expect(jsonified_tag[:name]).to eq(test_name)
    end
  end

  describe '#attach_to_transaction_with_id' do
    let(:transaction_id) { 11 }
    let!(:transaction_item) { create(:transaction_item, id: transaction_id, user: user) }

    it 'attaches the tag to the transaction with the given id' do
      tag = create(:tag, user: user)
      tag.attach_to_transaction_with_id(transaction_id)

      expect(tag.transaction_items.find_by(id: transaction_id)).to eq(transaction_item)
      expect(transaction_item.tags.find_by(id: tag.id)).to eq(tag)
    end

    it 'does not attach the tag to a transaction if the tag is invalid' do
      tag = build(:tag, name: '', user: user)
      tag.attach_to_transaction_with_id(transaction_id)

      expect(tag.invalid?).to be(true)
      expect(tag.transaction_items.find_by(id: transaction_id)).to be_nil
      expect(transaction_item.tags.find_by(id: tag.id)).to be_nil
    end

    it 'does not attach the tag to a transaction if the transaction does not exist' do
      tag = build(:tag, name: '', user: user)
      tag.attach_to_transaction_with_id(100)

      expect(tag.transaction_items.find_by(id: transaction_id)).to be_nil
      expect(transaction_item.tags.find_by(id: tag.id)).to be_nil
    end
  end

  describe '.find_or_create_tag_for' do
    it 'returns a tag with the given name if it exists' do
      name = 'purchase'
      tag_id = 3

      create(:tag, id: tag_id, name: name, user: user)

      prev_tag_count = Tag.count

      params = {
        name: name
      }

      tag = Tag.find_or_create_tag_for(user, params)
      new_tag_count = Tag.count

      expect(tag.id).to eq(tag_id)
      expect(tag.name).to eq(name)
      expect(tag.persisted?).to be(true)
      expect(new_tag_count - prev_tag_count).to eq(0)
    end

    it 'returns a tag with the given name if it exists (case insensitive)' do
      name = 'Test'
      tag_id = 5

      create(:tag, id: tag_id, name: name, user: user)

      prev_tag_count = Tag.count

      params = {
        name: name.downcase
      }

      tag = Tag.find_or_create_tag_for(user, params)
      new_tag_count = Tag.count

      expect(tag.id).to eq(tag_id)
      expect(tag.name).to eq(name)
      expect(tag.persisted?).to be(true)
      expect(new_tag_count - prev_tag_count).to eq(0)
    end

    it 'creates a tag for a user if the tag does not exist' do
      name = 'atm'

      params = {
        name: name
      }

      prev_tag_count = Tag.count

      tag = Tag.find_or_create_tag_for(user, params)
      new_tag_count = Tag.count

      expect(tag.name).to eq(name)
      expect(tag.persisted?).to be(true)
      expect(new_tag_count - prev_tag_count).to eq(1)
    end

    it 'fails gracefully for invalid tags with a name that is an empty string' do
      params = {
        name: ''
      }

      tag = Tag.find_or_create_tag_for(user, params)

      expect(tag.valid?).to be(false)
    end
  end
end
