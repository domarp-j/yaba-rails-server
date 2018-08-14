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

  describe '#attached_to_transaction?' do
    let(:transaction_item) { create(:transaction_item, user: user) }
    let(:tag) { create(:tag, user: user) }

    it 'returns truthy if tag-transaction relationship exists' do
      create(:tag_transaction, tag: tag, transaction_item: transaction_item)

      expect(tag.attached_to_transaction?(transaction_item.id)).to be_truthy
    end

    it 'returns falsey if tag-transaction relationship does not exist' do
      expect(tag.attached_to_transaction?(transaction_item.id)).to be_falsey
    end
  end

  describe '#remove_from_transaction_with_id' do
    let(:transaction_id) { 15 }
    let(:tag_id) { 100 }
    let(:tag_name) { 'test' }

    let(:transaction_item) { create(:transaction_item, id: transaction_id, user: user) }
    let(:tag) { create(:tag, id: tag_id, name: tag_name, user: user) }

    it 'removes the join between the tag and the transaction with the given id' do
      create(:tag_transaction, tag: tag, transaction_item: transaction_item)

      expect(tag.transaction_items.find_by(id: transaction_id)).to eq(transaction_item)
      expect(transaction_item.tags.find_by(id: tag.id)).to eq(tag)

      tag.remove_from_transaction_with_id(transaction_id)

      expect(tag.transaction_items.find_by(id: transaction_id)).to be_nil
      expect(transaction_item.tags.find_by(id: tag.id)).to be_nil
    end

    it 'fails gracefully if the tag-transaction relationship does not exist' do
      another_tag = create(:tag, id: tag_id + 1, name: 'another-tag', user: user)

      another_tag.remove_from_transaction_with_id(transaction_id)

      expect(tag.transaction_items.find_by(id: transaction_id)).to be_nil
      expect(transaction_item.tags.find_by(id: another_tag.id)).to be_nil
    end
  end

  describe '#update_for_transaction_with_id' do
    let(:transaction_id) { 16 }
    let(:tag_id) { 100 }
    let(:tag_name) { 'test' }
    let(:new_tag_name) { 'test-new-name' }

    let(:transaction_item) { create(:transaction_item, id: transaction_id, user: user) }
    let(:tag) { create(:tag, id: tag_id, name: tag_name, user: user) }
    let!(:tag_transaction) { create(:tag_transaction, tag: tag, transaction_item: transaction_item) }

    it 'updates a tag with a new name' do
      tag_params = {
        id: tag_id,
        name: new_tag_name
      }

      expect(tag.name).to eq(tag_name)

      tag.update_for_transaction_with_id(transaction_id, user, tag_params)
      updated_tag = Tag.find_by(id: tag_id)

      expect(updated_tag.name).to eq(new_tag_name)
    end

    it 'returns nil if tag is not found' do
      tag_params = {
        id: tag_id + 1,
        name: new_tag_name
      }

      expect(tag.name).to eq(tag_name)

      result = tag.update_for_transaction_with_id(transaction_id, user, tag_params)
      expect(result).to be_nil

      tag = Tag.find_by(id: tag_id)
      expect(tag.name).to eq(tag_name)
    end

    it 'does not update the tag for another user' do
      another_user = create(:user, email: 'helloworld@test.com')
      another_transaction = create(:transaction_item, user: user)

      tag_params = {
        id: tag_id,
        name: new_tag_name
      }

      expect(tag.name).to eq(tag_name)

      tag.update_for_transaction_with_id(another_transaction.id, another_user, tag_params)

      tag = Tag.find_by(id: tag_id)
      expect(tag.name).to eq(tag_name)
    end
  end

  describe '.find_tag_for' do
    let(:name) { 'purchase' }
    let(:tag_id) { 3 }
    let(:create_tag) { create(:tag, id: tag_id, name: name, user: user) }

    it 'returns a tag with the given ID if it exists' do
      create_tag

      prev_tag_count = Tag.count

      params = {
        id: tag_id
      }

      tag = Tag.find_tag_for(user, params)
      new_tag_count = Tag.count

      expect(tag.id).to eq(tag_id)
      expect(tag.name).to eq(name)
      expect(tag.persisted?).to be(true)
      expect(new_tag_count - prev_tag_count).to eq(0)
    end

    it 'returns a tag with the given name if it exists' do
      create_tag

      prev_tag_count = Tag.count

      params = {
        name: name
      }

      tag = Tag.find_tag_for(user, params)
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

      tag = Tag.find_tag_for(user, params)
      new_tag_count = Tag.count

      expect(tag.id).to eq(tag_id)
      expect(tag.name).to eq(name)
      expect(tag.persisted?).to be(true)
      expect(new_tag_count - prev_tag_count).to eq(0)
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
