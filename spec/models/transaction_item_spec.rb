require 'rails_helper'

RSpec.describe TransactionItem, type: :model do
  limit_default = TransactionItem::DEFAULT_LIMIT

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
    # This test covers complex scenarios for fetching transactions
    # For basic, "happy-path" specs, please refer to the transaction item requests spec

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

    it 'does not provide duplicate transaction items over multiple fetches in sequence' do
      result1 = TransactionItem.fetch_transactions_for(user, limit: 3, page: 0, sort_attribute: 'date', sort_order: 'desc')
      result2 = TransactionItem.fetch_transactions_for(user, limit: 3, page: 1, sort_attribute: 'date', sort_order: 'desc')
      result3 = TransactionItem.fetch_transactions_for(user, limit: 3, page: 2, sort_attribute: 'date', sort_order: 'desc')

      trans_ids = [
        result1[:transactions],
        result2[:transactions],
        result3[:transactions]
      ].flatten.pluck(:id)
      uniq_trans_ids = trans_ids.uniq

      expect(trans_ids).to eq(uniq_trans_ids), 'Duplicate transactions were returned over sequential fetches'
    end

    context 'with tag names' do
      let(:tag0) { create(:tag, name: 'tag0', user: user) }
      let(:tag1) { create(:tag, name: 'tag1', user: user) }
      let(:tag2) { create(:tag, name: 'tag2', user: user) }

      let(:tag_list0) { [tag0] }
      let(:tag_list1) { [tag0, tag1] }
      let(:tag_list2) { [tag0, tag1, tag2] }

      before do
        # "Purchase" transaction uses only the first tag
        create(:tag_transaction, tag_id: tag0.id, transaction_item_id: purchase.id)

        # "Large income" transaction uses only two tags
        create(:tag_transaction, tag_id: tag0.id, transaction_item_id: large_income.id)
        create(:tag_transaction, tag_id: tag1.id, transaction_item_id: large_income.id)

        # "Large purchase" transaction uses all three tags
        create(:tag_transaction, tag_id: tag0.id, transaction_item_id: large_purchase.id)
        create(:tag_transaction, tag_id: tag1.id, transaction_item_id: large_purchase.id)
        create(:tag_transaction, tag_id: tag2.id, transaction_item_id: large_purchase.id)
      end

      context 'match all tags (default)' do
        it 'fetches all transactions with all of the following tag names (case 1)' do
          result = TransactionItem.fetch_transactions_for(user, tag_names: tag_list0.map(&:name))

          expect(result[:transactions].length).to eq(3)
          result[:transactions].each do |transaction_item|
            expect([purchase, large_income, large_purchase]).to include(transaction_item)
          end
        end

        it 'fetches all transactions with all of the following tag names (case 2)' do
          result = TransactionItem.fetch_transactions_for(user, tag_names: tag_list1.map(&:name))

          expect(result[:transactions].count).to eq(2)
          result[:transactions].each do |transaction_item|
            expect([large_income, large_purchase]).to include(transaction_item)
          end
        end

        it 'fetches all transactions with all of the following tag names (case 3)' do
          result = TransactionItem.fetch_transactions_for(user, tag_names: tag_list2.map(&:name))

          expect(result[:transactions].length).to eq(1)
          expect(result[:transactions].first).to eq(large_purchase)
        end

        it 'does not return any transactions if any of the tag names are not mapped to a tag' do
          bad_tag_name_list = tag_list0.map(&:name) + ['not-a-tag']
          result = TransactionItem.fetch_transactions_for(user, tag_names: bad_tag_name_list)

          expect(result[:transactions].length).to eq(0)
        end
      end

      context 'match any tags' do
        it 'fetches transactions with any of the following tag names (case 1)' do
          result = TransactionItem.fetch_transactions_for(
            user,
            tag_names: tag_list0.map(&:name),
            match_all_tags: false
          )

          expect(result[:transactions].length).to eq(3)
          result[:transactions].each do |transaction_item|
            expect([purchase, large_income, large_purchase]).to include(transaction_item)
          end
        end

        it 'fetches transactions with any of the following tag names (case 2)' do
          result = TransactionItem.fetch_transactions_for(
            user,
            tag_names: tag_list1.map(&:name),
            match_all_tags: false
          )

          expect(result[:transactions].length).to eq(3)
          result[:transactions].each do |transaction_item|
            expect([purchase, large_income, large_purchase]).to include(transaction_item)
          end
        end

        it 'fetches transactions with any of the following tag names (case 3)' do
          result = TransactionItem.fetch_transactions_for(
            user,
            tag_names: tag_list2.map(&:name),
            match_all_tags: false
          )

          expect(result[:transactions].length).to eq(3)
          result[:transactions].each do |transaction_item|
            expect([purchase, large_income, large_purchase]).to include(transaction_item)
          end
        end
      end
    end

    context 'with date range' do
      let(:first_day) { 1 }
      let(:last_day) { 5 }

      let(:day_range) { first_day..last_day }

      before do
        TransactionItem.destroy_all

        (first_day..last_day).each do |x|
          create_list(:transaction_item, x, date: Time.parse("January #{x} 2000"), user: user)
        end
      end

      it 'fetches transactions for a given date range' do
        from_date = "2000-01-0#{day_range.first}"
        to_date = "2000-01-0#{day_range.last}"

        result = TransactionItem.fetch_transactions_for(user, from_date: from_date, to_date: to_date)

        expect(result[:transactions].length).to eq(day_range.sum)
        expect(result[:transactions].first.date).to eq(to_date)
        expect(result[:transactions].last.date).to eq(from_date)
      end

      it 'fetches transactions from a provided from_date even if to_date is not present' do
        from_date = "2000-01-0#{day_range.first}"

        result = TransactionItem.fetch_transactions_for(user, from_date: from_date)

        latest_trans = TransactionItem.all.order(date: :asc).last

        expect(result[:transactions].length).to eq(day_range.sum)
        expect(result[:transactions].first.date).to eq(latest_trans.date)
        expect(result[:transactions].last.date).to eq(from_date)
      end

      it 'fetches transactions from a provided from_date even if to_date is not present' do
        to_date = "2000-01-0#{day_range.last}"

        result = TransactionItem.fetch_transactions_for(user, to_date: to_date)

        earliest_trans = TransactionItem.all.order(date: :asc).first

        expect(result[:transactions].length).to eq(day_range.sum)
        expect(result[:transactions].first.date).to eq(to_date)
        expect(result[:transactions].last.date).to eq(earliest_trans.date)
      end
    end

    context 'with description for partial-match search' do
      let(:description_partial) { 'Some Purc' }

      # Descriptions that should match
      let(:positive_description_matches) do
        [
          'Some purc',
          'Some Purc',
          'Some purchase',
          'some purchase',
          'sOmE pUrChAsE'
        ]
      end

      # Descriptions that should not match
      let(:negative_description_matches) do
        [
          'Not at all a close description',
          'Som Purc',
          'Sume Purc',
          'A Purchase'
        ]
      end

      before do
        (positive_description_matches + negative_description_matches).each do |desc|
          create(:transaction_item, description: desc, user: user)
        end
      end

      it 'fetches transactions that partially match provided description' do
        result = TransactionItem.fetch_transactions_for(
          user,
          description: description_partial
        )

        expect(result[:transactions].length).to eq(positive_description_matches.length)
        result[:transactions].each do |trans|
          expect(positive_description_matches).to include(trans.description)
        end
      end
    end

    context 'all possible queries' do
      # Tags that will be used for the query
      let(:tag0) { create(:tag, name: 'tag0', user: user) }
      let(:tag1) { create(:tag, name: 'tag1', user: user) }

      # Tag that will not be used for the query
      let(:tag2) { create(:tag, name: 'tag2', user: user) }

      # From-date for query
      let(:from_date_query) { '2018-08-14' }

      # To-date for query
      let(:to_date_query) { '2018-11-28' }

      # Description that will be used for the query
      let(:desc_query) { 'test' }

      # All of the transactions that are expected from the tests
      let(:trans0) { create(:transaction_item, description: 'test 123', date: Time.parse('August 15 2018'), user: user) }
      let(:trans1) { create(:transaction_item, description: '123 test', date: Time.parse('September 30 2018'), user: user) }
      let(:trans2) { create(:transaction_item, description: 'TEST', date: Time.parse('October 7 2018'), user: user) }
      let(:trans3) { create(:transaction_item, description: 'EST TEST', date: Time.parse('October 31 2018'), user: user) }
      let(:trans4) { create(:transaction_item, description: 'tttestttt', date: Time.parse('November 20 2018'), user: user) }
      let(:trans5) { create(:transaction_item, description: 'I must attest', date: Time.parse('November 28 2018'), user: user) }

      before do
        # Give the transactions above the tags that will be used for the query
        [trans0, trans1, trans2, trans3, trans4, trans5].each do |trans|
          create(:tag_transaction, tag_id: tag0.id, transaction_item_id: trans.id)
          create(:tag_transaction, tag_id: tag1.id, transaction_item_id: trans.id)
        end

        # Add transactions that do not have all of the required tags
        # These transactions will be expected from the "matches any tag" test
        trans_list_without_tag = create_list(
          :transaction_item,
          5,
          description: desc_query,
          date: Time.parse('October 1 2018'),
          user: user
        )
        trans_list_without_tag.each do |trans|
          create(:tag_transaction, tag_id: tag0.id, transaction_item_id: trans.id)
          create(:tag_transaction, tag_id: tag2.id, transaction_item_id: trans.id)
        end

        # Add transactions that are outside of the date range
        ['July 1 2018', 'August 3 2018', 'December 15 2018', 'January 11 2019'].each do |date_str|
          trans = create(:transaction_item, description: desc_query, date: Time.parse(date_str), user: user)
          create(:tag_transaction, tag_id: tag0.id, transaction_item_id: trans.id)
          create(:tag_transaction, tag_id: tag1.id, transaction_item_id: trans.id)
        end

        # Add transactions that do not partially match the provided description
        trans_list_wrong_desc = create_list(
          :transaction_item,
          5,
          description: 'Not a match',
          date: Time.parse('October 1 2018'),
          user: user
        )
        trans_list_wrong_desc.each do |trans|
          create(:tag_transaction, tag_id: tag0.id, transaction_item_id: trans.id)
          create(:tag_transaction, tag_id: tag1.id, transaction_item_id: trans.id)
        end
      end

      it 'fetches the correct transactions' do
        result = TransactionItem.fetch_transactions_for(
          user,
          tag_names: [tag0, tag1].map(&:name),
          description: desc_query,
          from_date: from_date_query,
          to_date: to_date_query
        )

        expect(result[:transactions].length).to eq(6)
      end

      it 'fetches the correct transactions, matching any tag' do
        # Create some transactions with either of tag0 or tag1
        trans0 = create(:transaction_item, description: desc_query, date: Time.parse('October 1 2018'), user: user)
        create(:tag_transaction, tag_id: tag0.id, transaction_item_id: trans0.id)
        trans1 = create(:transaction_item, description: desc_query, date: Time.parse('October 1 2018'), user: user)
        create(:tag_transaction, tag_id: tag1.id, transaction_item_id: trans1.id)

        result = TransactionItem.fetch_transactions_for(
          user,
          tag_names: [tag0, tag1].map(&:name),
          description: desc_query,
          from_date: from_date_query,
          to_date: to_date_query,
          match_all_tags: false
        )

        expect(result[:transactions].length).to eq(13)
      end
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
