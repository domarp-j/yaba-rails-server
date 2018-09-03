require 'rails_helper'

RSpec.describe TransactionItem, type: :model do
  limit_default = TransactionItem::DEFAULT_LIMIT
  page_default = TransactionItem::FIRST_PAGE

  let(:user) { create(:user) }

  describe '#jsonify' do
    let(:test_description) { 'Transaction' }
    let(:test_value) { -100 }

    let(:transaction_item) do
      create(:transaction_item,
             description: test_description,
             value: test_value,
             user: user)
    end

    let(:first_tag) { create(:tag, name: 'tag_a', user: user) }
    let(:second_tag) { create(:tag, name: 'tag_b', user: user) }

    let(:first_tag_transaction) do
      create(:tag_transaction, tag: first_tag, transaction_item: transaction_item)
    end
    let(:second_tag_transaction) do
      create(:tag_transaction, tag: second_tag, transaction_item: transaction_item)
    end

    let(:jsonified_transaction) { transaction_item.jsonify }

    it 'returns a JSON with a description field' do
      expect(jsonified_transaction[:description]).to eq(test_description)
    end

    it 'returns a JSON with a value field' do
      expect(jsonified_transaction[:value]).to eq(test_value)
    end

    it 'returns a JSON with a date field' do
      expect(jsonified_transaction[:date]).not_to be_nil
    end

    it 'returns a JSON with an array of the transaction\'s tags in alphabetical order' do
      first_tag_transaction
      second_tag_transaction

      expect(jsonified_transaction[:tags]).to eq([
                                                   { id: first_tag.id, name: first_tag.name },
                                                   { id: second_tag.id, name: second_tag.name }
                                                 ])
    end
  end

  describe '#attached_to_tag_with_name?' do
    let(:transaction) { create(:transaction_item, user: user) }
    let(:tag_name) { 'test' }

    it 'returns truthy if transaction has tag with the given name' do
      tag = create(:tag, name: tag_name, user: user)
      create(:tag_transaction, tag_id: tag.id, transaction_item_id: transaction.id)

      expect(transaction.attached_to_tag_with_name?(tag_name)).to be(true)
    end

    it 'returns falsey if transaction does not have tag with the given name' do
      expect(transaction.attached_to_tag_with_name?(tag_name)).to be(false)
    end
  end

  describe '#destroy_with_tags!' do
    let(:transaction) { create(:transaction_item, user: user) }
    let(:tag) { create(:tag, user: user) }

    it 'destroys the transaction' do
      transaction.destroy_with_tags!

      expect(TransactionItem.find_by(id: transaction.id)).to be_nil
    end

    it 'destroys tags that will be orphaned by the transaction\'s deletion' do
      create(:tag_transaction, tag_id: tag.id, transaction_item_id: transaction.id)

      transaction.destroy_with_tags!

      expect(Tag.find_by(id: tag.id)).to be_nil
    end

    it 'does not destroy tags that are associated with other transactions' do
      create(:tag_transaction, tag_id: tag.id, transaction_item_id: transaction.id)

      another_transaction = create(:transaction_item, description: 'another trans', user: user)
      create(:tag_transaction, tag_id: tag.id, transaction_item_id: another_transaction.id)

      transaction.destroy_with_tags!

      expect(Tag.find_by(id: tag.id)).to eq(tag)
    end
  end

  describe '.fetch_transactions_for' do
    before do
      # Bulk of old incomes
      create_list(:transaction_item, limit_default, :repeated_income, :three_weeks_ago, user: user)

      # Bulk of old puchases
      create_list(:transaction_item, limit_default, :repeated_purchase, :one_week_ago, user: user)
    end

    # A few recent purchases & incomes
    let!(:purchase) { create(:transaction_item, :purchase, user: user, date: 3.days.ago) }
    let!(:large_income) { create(:transaction_item, :large_income, user: user, date: 2.days.ago) }
    let!(:large_purchase) { create(:transaction_item, :large_purchase, user: user, date: 1.days.ago) }

    it "fetches #{limit_default} transactions by default" do
      result = TransactionItem.fetch_transactions_for(user)

      expect(result.count).to eq(limit_default)
    end

    it "fetches a user's transactions starting at index #{page_default} by default" do
      result = TransactionItem.fetch_transactions_for(user)

      expect(result[0].date).to be_within(1.hour).of(1.days.ago)
    end

    it 'fetches a custom number of transactions if a limit is provided' do
      limit = 3

      result = TransactionItem.fetch_transactions_for(user, limit: limit)

      expect(result.count).to eq(limit)
    end

    it 'fetches transactions with an offset if a page number is provided' do
      page = 1

      result = TransactionItem.fetch_transactions_for(user, page: page)

      expect(result[0].date).to be_within(1.hour).of(1.weeks.ago)
    end

    it 'fetches transactions with a limit and an offset if both are provided' do
      limit = 3
      page = 1

      result = TransactionItem.fetch_transactions_for(user, limit: limit, page: page)

      expect(result.count).to eq(limit)
      result.each do |transaction_item|
        expect(transaction_item.date).to be_within(1.hour).of(1.weeks.ago)
      end
    end

    it 'sorts transactions on the same date at descending created_at order' do
      trans1 = create(:transaction_item, created_at: 5.minutes.ago, user: user)
      trans2 = create(:transaction_item, created_at: 10.minutes.ago, user: user)
      trans3 = create(:transaction_item, created_at: 15.minutes.ago, user: user)

      result = TransactionItem.fetch_transactions_for(user)

      expect(result[0..2]).to eq([trans1, trans2, trans3])
    end

    it 'does not remove duplicate transaction items over multiple fetches in sequence' do
      result1 = TransactionItem.fetch_transactions_for(user, limit: 3, page: 0)
      result2 = TransactionItem.fetch_transactions_for(user, limit: 3, page: 1)
      result3 = TransactionItem.fetch_transactions_for(user, limit: 3, page: 2)

      trans_ids = [result1, result2, result3].flatten.pluck(:id)
      uniq_trans_ids = trans_ids.uniq

      expect(trans_ids).to eq(uniq_trans_ids), 'Duplicate transactions were returned over sequential fetches'
    end

    context 'with tag names' do
      let(:tag1) { create(:tag, name: 'tag1', user: user) }
      let(:tag2) { create(:tag, name: 'tag2', user: user) }
      let(:tag3) { create(:tag, name: 'tag3', user: user) }

      let(:tag_list1) { [tag1] }
      let(:tag_list2) { [tag1, tag2] }
      let(:tag_list3) { [tag1, tag2, tag3] }

      before do
        # "Purchase" transaction uses only the first tag
        create(:tag_transaction, tag_id: tag1.id, transaction_item_id: purchase.id)

        # "Large income" transaction uses only two tags
        create(:tag_transaction, tag_id: tag1.id, transaction_item_id: large_income.id)
        create(:tag_transaction, tag_id: tag2.id, transaction_item_id: large_income.id)

        # "Large purchase" transaction uses all three tags
        create(:tag_transaction, tag_id: tag1.id, transaction_item_id: large_purchase.id)
        create(:tag_transaction, tag_id: tag2.id, transaction_item_id: large_purchase.id)
        create(:tag_transaction, tag_id: tag3.id, transaction_item_id: large_purchase.id)
      end

      it "fetches all transactions with the following tag names (case 1)" do
        result = TransactionItem.fetch_transactions_for(user, tag_names: tag_list1.map(&:name))

        expect(result.count).to eq(3)
        result.each do |transaction_item|
          expect([purchase, large_income, large_purchase]).to include(transaction_item)
        end
      end

      it "fetches all transactions with the following tag names (case 2)" do
        result = TransactionItem.fetch_transactions_for(user, tag_names: tag_list2.map(&:name))

        expect(result.count).to eq(2)
        result.each do |transaction_item|
          expect([large_income, large_purchase]).to include(transaction_item)
        end
      end

      it "fetches all transactions with the following tag names (case 3)" do
        result = TransactionItem.fetch_transactions_for(user, tag_names: tag_list3.map(&:name))

        expect(result.count).to eq(1)
        expect(result.first).to eq(large_purchase)
      end
    end

    it 'sorts so that most recent transactions are first' do
      result = TransactionItem.fetch_transactions_for(user, limit: TransactionItem.count)

      expect(result[0].date).to be_within(1.hour).of(1.days.ago)
      expect(result[1].date).to be_within(1.hour).of(2.days.ago)
      expect(result[2].date).to be_within(1.hour).of(3.days.ago)
      expect(result[3].date).to be_within(1.hour).of(1.weeks.ago)
      expect(result.last.date).to be_within(1.hour).of(3.weeks.ago)
    end
  end

  describe '.build_transaction_for' do
    let(:description) { 'Purchase' }
    let(:value) { -10.3 }
    let(:date) { '2018-07-29' }

    it 'builds a transaction item for a user' do
      params = {
        description: description,
        value: value,
        date: date
      }

      trans = TransactionItem.build_transaction_for(user, params)

      expect(trans.description).to eq(description)
      expect(trans.value).to eq(value.to_f)
      expect(trans.date).to eq(Time.parse(params[:date]))
      expect(trans.new_record?).to be(true)
    end
  end

  describe '.update_transaction_for' do
    let(:transaction_id) { 93 }
    let!(:transaction_item) { create(:transaction_item, id: transaction_id, user: user) }

    it 'updates the description if the param is provided' do
      params = {
        id: transaction_id,
        description: 'Updated description'
      }

      trans = TransactionItem.update_transaction_for(user, params)

      expect(trans.description).to eq(params[:description])
    end

    it 'updates the value if the param is provided as a float' do
      params = {
        id: transaction_id,
        value: -10.3
      }

      trans = TransactionItem.update_transaction_for(user, params)

      expect(trans.value).to eq(params[:value])
    end

    it 'updates the value if the param is provided as as tring' do
      params = {
        id: transaction_id,
        value: '-10.3'
      }

      trans = TransactionItem.update_transaction_for(user, params)

      expect(trans.value).to eq(params[:value].to_f)
    end

    it 'updates the date if the param is provided' do
      params = {
        id: transaction_id,
        date: '2019-03-18'
      }

      trans = TransactionItem.update_transaction_for(user, params)

      expect(trans.date).to eq(Time.parse(params[:date]))
    end

    it 'fails gracefully if the transaction is not found' do
      params = {
        id: 100,
        description: 'Updated description'
      }

      trans = TransactionItem.update_transaction_for(user, params)

      expect(trans).to be_nil
    end
  end
end
