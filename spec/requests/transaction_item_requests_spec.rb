require 'rails_helper'

RSpec.describe 'transaction items requests:', type: :request do
  limit_default = TransactionItem::DEFAULT_LIMIT

  let(:user) { create(:user, email: 'test1@example.com') }

  before do
    sign_in user
  end

  context 'fetching transactions' do
    def fetch_request(params: nil)
      get transaction_items_path,
          params: params,
          headers: devise_request_headers
    end

    def content_transactions
      content['transactions']
    end

    def assert_success
      assert_response_success(expected_message: 'Transactions successfully fetched')
    end

    def assert_failure
      assert_response_failure(expected_message: 'Could not fetch transactions')
    end

    it 'returns the total number of transactions' do
      total_trans = 50
      create_list(:transaction_item, total_trans, :purchase, user: user)

      fetch_request

      assert_success
      expect(content['count']).to eq(total_trans)
    end

    it 'returns the total amount of the transactions' do
      create_list(:transaction_item, 10, :purchase, user: user)

      fetch_request

      expected_sum = user.transaction_items.map(&:value).reduce(:+)

      assert_success
      expect(content['total_amount']).to eq(expected_sum)
    end

    it "returns all of the user's transactions if (s)he has less than #{limit_default} items" do
      create_list(:transaction_item, limit_default - 1, :purchase, user: user)

      fetch_request

      assert_success
      expect(content_transactions.length).to eq(limit_default - 1)
    end

    it "returns just #{limit_default} transactions if (s)he has more than #{limit_default} transactions" do
      create_list(:transaction_item, limit_default + 1, :purchase, user: user)

      fetch_request

      assert_success
      expect(content_transactions.length).to eq(limit_default)
    end

    it 'returns a specific number of the user\'s latest transaction items if limit is given as a parameter' do
      create_list(:transaction_item, 10, :purchase, :two_weeks_ago, user: user)
      create_list(:transaction_item, 5, :purchase, :one_week_ago, user: user)

      fetch_request(params: { limit: '5' })

      assert_success
      expect(content_transactions.length).to eq(5)
      content_transactions.each do |transaction|
        expect(Time.parse(transaction['date'])).to be_within(1.hour).of(1.week.ago)
      end
    end

    it 'returns transactions with an offset if page is given as a parameter' do
      create_list(:transaction_item, limit_default, :purchase, :two_weeks_ago, user: user)
      create_list(:transaction_item, limit_default, :purchase, :one_week_ago, user: user)

      fetch_request(params: { page: '1' })

      assert_success
      expect(content_transactions.length).to eq(limit_default)
      content_transactions.each do |transaction|
        expect(Time.parse(transaction['date'])).to be_within(1.hour).of(2.week.ago)
      end
    end

    it 'returns transactions with a limit and offset if limit & page are given as parameters' do
      create_list(:transaction_item, 10, :purchase, :two_weeks_ago, user: user)
      create_list(:transaction_item, 5, :purchase, :one_week_ago, user: user)

      fetch_request(params: { limit: '6', page: '1' })

      assert_success
      transaction = content_transactions[0]
      expect(Time.parse(transaction['date'])).to be_within(1.hour).of(2.week.ago)
    end

    context 'tag params' do
      let(:tag_names) { ['some-tag-1', 'some-tag-2'] }

      let(:tag0) { create(:tag, name: tag_names[0], user: user) }
      let(:tag1) { create(:tag, name: tag_names[1], user: user) }

      let(:tag_0_trans_count) { 4 }
      let(:tag_1_trans_count) { 3 }
      let(:tag_0_1_trans_count) { 5 }

      let(:trans_with_tags_count) do
        tag_0_trans_count + tag_1_trans_count + tag_0_1_trans_count
      end

      before do
        # Transactions with only tag0
        create_list(:transaction_item, tag_0_trans_count, :large_purchase, user: user).each do |trans|
          create(:tag_transaction, tag_id: tag0.id, transaction_item_id: trans.id)
        end

        # Transactions with only tag1
        create_list(:transaction_item, tag_1_trans_count, :large_income, user: user).each do |trans|
          create(:tag_transaction, tag_id: tag1.id, transaction_item_id: trans.id)
        end

        # Transactions with both tag0 and tag1
        create_list(:transaction_item, tag_0_1_trans_count, :purchase, user: user).each do |trans|
          create(:tag_transaction, tag_id: tag0.id, transaction_item_id: trans.id)
          create(:tag_transaction, tag_id: tag1.id, transaction_item_id: trans.id)
        end

        # Transactions without any tags
        create_list(:transaction_item, 10, :income, user: user)
      end

      it 'returns transactions that contain *all* of the provided tags' do
        fetch_request(params: { tag_names: tag_names })

        assert_success
        expect(content_transactions.length).to eq(tag_0_1_trans_count)
        content_transactions.each do |trans_json|
          tag_names_in_response = trans_json['tags'].map { |tag_json| tag_json['name'] }
          tag_names_in_response.each { |tag| expect(tag_names).to include(tag) }
        end
      end

      it 'returns transactions that contain *all* of the provided tags (case insensitive)' do
        fetch_request(params: { tag_names: tag_names.map(&:upcase) })

        assert_success
        expect(content_transactions.length).to eq(tag_0_1_trans_count)
        content_transactions.each do |trans_json|
          tag_names_in_response = trans_json['tags'].map { |tag_json| tag_json['name'] }
          tag_names_in_response.each { |tag| expect(tag_names).to include(tag) }
        end
      end

      it 'returns transactions that contain *any* of the provided tags' do
        fetch_request(params: { tag_names: tag_names, match_all_tags: false })

        assert_success
        expect(content_transactions.length).to eq(trans_with_tags_count)
      end
    end

    context 'date range params' do
      let!(:first_expected_trans) { create(:transaction_item, date: Time.parse('July 28 2018'), user: user) }
      let!(:last_expected_trans) { create(:transaction_item, date: Time.parse('September 3 2018'), user: user) }

      before do
        create(:transaction_item, date: Time.parse('July 3 2018'), user: user)
        create(:transaction_item, date: Time.parse('August 15 2018'), user: user)
        create(:transaction_item, date: Time.parse('October 5 2018'), user: user)
        create(:transaction_item, date: Time.parse('October 30 2018'), user: user)
      end

      it 'returns transactions within a specific date range if a from_date or to_date is provided' do
        fetch_request(params: { from_date: '2018-07-15', to_date: '2018-09-03' })

        assert_success
        expect(content_transactions.length).to eq(3)
        expect(content_transactions.first['id']).to eq(last_expected_trans.id)
        expect(content_transactions.last['id']).to eq(first_expected_trans.id)
      end

      it 'does not throw an error if any date range params are empty' do
        fetch_request(params: { from_date: '', to_date: '' })

        assert_success
        expect(content_transactions.length).to eq(4)
      end
    end

    context 'description param' do
      let(:desc) { 'income' }

      before do
        create(:transaction_item, description: 'income', user: user)
        create(:transaction_item, description: 'INCOME', user: user)
        create(:transaction_item, description: 'Income', user: user)
        create(:transaction_item, description: 'incomex', user: user)
        create(:transaction_item, description: 'xincome', user: user)
        create(:transaction_item, description: 'xincome', user: user)
        create(:transaction_item, description: 'xincomex', user: user)
      end

      it 'returns transactions that partially match a provided description' do
        fetch_request(params: { description: desc })

        assert_success
        expect(content_transactions.length).to eq(7)
      end

      it 'does not throw an error if the description param is empty' do
        fetch_request(params: { description: '' })

        assert_success
      end
    end

    it 'does not return transaction items for other users' do
      another_user = create(:user, email: 'test2@example.com')
      create_list(:transaction_item, 5, :large_income, user: another_user)

      fetch_request

      assert_failure
    end

    it 'returns a failure if no transactions are found' do
      another_user = create(:user, email: 'test3@example.com')
      sign_in another_user

      fetch_request

      assert_failure
    end

    it 'does not return a failure if transactions are not returned but page is > 0' do
      limit = 10
      create_list(:transaction_item, limit, user: user)

      fetch_request(params: { limit: limit.to_s, page: '1' })

      assert_success
      expect(content_transactions).to eq([])
    end

    context 'sorting' do
      def content_transactions_ids
        content_transactions.map { |trans| trans['id'] }
      end

      let!(:trans0) do
        create(:transaction_item, description: 'Purchase A', value: -132.8, date: Time.parse('January 1 2014'), user: user)
      end
      let!(:trans1) do
        create(:transaction_item, description: 'purchase B', value: -2510.3, date: Time.parse('March 31 1990'), user: user)
      end
      let!(:trans2) do
        create(:transaction_item, description: 'Purchase C', value: -0.01, date: Time.parse('December 14 2017'), user: user)
      end
      let!(:trans3) do
        create(:transaction_item, description: 'Income A', value: 2000, date: Time.parse('August 18 2015'), user: user)
      end
      let!(:trans4) do
        create(:transaction_item, description: 'income B', value: 0.1, date: Time.parse('January 3 2014'), user: user)
      end

      let(:trans_by_date_asc) { [trans1, trans0, trans4, trans3, trans2] }
      let(:trans_by_desc_asc) { [trans3, trans4, trans0, trans1, trans2] }
      let(:trans_by_val_asc) { [trans1, trans0, trans2, trans4, trans3] }

      let(:trans_id_by_date_asc) { trans_by_date_asc.map(&:id) }
      let(:trans_id_by_desc_asc) { trans_by_desc_asc.map(&:id) }
      let(:trans_id_by_val_asc) { trans_by_val_asc.map(&:id) }

      it 'sorts by descending date by default' do
        fetch_request

        assert_success
        expect(trans_id_by_date_asc.reverse).to eq(content_transactions_ids)
      end

      it 'sorts by ascending date' do
        fetch_request(params: { sort_attribute: 'date', sort_order: 'asc' })

        assert_success
        expect(trans_id_by_date_asc).to eq(content_transactions_ids)
      end

      it 'sorts by descending date (params explicitly provided)' do
        fetch_request(params: { sort_attribute: 'date', sort_order: 'desc' })

        assert_success
        expect(trans_id_by_date_asc.reverse).to eq(content_transactions_ids)
      end

      it 'sorts by ascending description (alphabetically)' do
        fetch_request(params: { sort_attribute: 'description', sort_order: 'asc' })

        assert_success
        expect(trans_id_by_desc_asc).to eq(content_transactions_ids)
      end

      it 'sorts by descending description (reverse-alphabetically)' do
        fetch_request(params: { sort_attribute: 'description', sort_order: 'desc' })

        assert_success
        expect(trans_id_by_desc_asc.reverse).to eq(content_transactions_ids)
      end

      it 'sorts by ascending value' do
        fetch_request(params: { sort_attribute: 'value', sort_order: 'asc' })

        assert_success
        expect(trans_id_by_val_asc).to eq(content_transactions_ids)
      end

      it 'sorts by descending descending value' do
        fetch_request(params: { sort_attribute: 'value', sort_order: 'desc' })

        assert_success
        expect(trans_id_by_val_asc.reverse).to eq(content_transactions_ids)
      end

      it 'fails if an invalid sort attribute param is provided' do
        fetch_request(params: { sort_attribute: 'invalid', sort_order: 'desc' })

        assert_failure
        expect(content).to include(
          "Invalid sort attribute. Should be one of: #{TransactionItemsController::SORT_ATTRIBUTE_PARAMS}"
        )
      end

      it 'fails if an invalid sort order param is provided' do
        fetch_request(params: { sort_attribute: 'date', sort_order: 'invalid' })

        assert_failure
        expect(content).to include(
          "Invalid sort order. Should be one of: #{TransactionItemsController::SORT_ORDER_PARAMS}"
        )
      end
    end
  end

  context 'adding a new transaction' do
    def create_request(params:)
      post add_transaction_item_path,
           params: params,
           headers: devise_request_headers
    end

    def assert_success
      assert_response_success(expected_message: 'Transaction successfully created')
    end

    it 'succeeds for a valid description, value, and date ' do
      description = 'Some purchase'
      value = '-12.3'
      date = '2018-07-29'

      create_request(params: { description: description, value: value, date: date })

      added_transaction = TransactionItem.find_by(
        description: description,
        value: value.to_f,
        date: Time.parse(date)
      )

      assert_success
      expect(content['id']).to eq(added_transaction.id)
      expect(content['description']).to eq(description)
      expect(content['value']).to eq(value.to_f)
      expect(Time.parse(content['date'])).to eq(Time.parse(date))
      expect(added_transaction).not_to be_nil, 'Expected to find the newly-added transaction'
    end
  end

  context 'updating a transaction' do
    def update_request(params:)
      post update_transaction_item_path,
           params: params,
           headers: devise_request_headers
    end

    def assert_success
      assert_response_success(expected_message: 'Transaction successfully updated')
    end

    let(:id) { 1 }
    let(:description) { 'Purchase' }
    let(:value) { -10.3 }
    let(:date) { Time.parse('March 17 2018') }

    before do
      create(:transaction_item, id: id, description: description, value: value, date: date, user: user)
    end

    it 'succeeds for valid description' do
      transaction = TransactionItem.find(id)
      expect(transaction.description).to eq(description)

      updated_description = 'Updated description'
      update_request(params: { id: id, description: updated_description })

      assert_success
      transaction = TransactionItem.find(id)
      expect(transaction.description).to eq(updated_description)
    end

    it 'succeeds for valid value' do
      transaction = TransactionItem.find(id)
      expect(transaction.value).to eq(value)

      updated_value = 100.71
      update_request(params: { id: id, value: updated_value })

      assert_success
      transaction = TransactionItem.find(id)
      expect(transaction.value).to eq(updated_value)
    end

    it 'succeeds for valid date' do
      transaction = TransactionItem.find(id)
      expect(transaction.date).to eq(date)

      updated_date = '2018-07-29'
      update_request(params: { id: id, date: updated_date })

      assert_success
      transaction = TransactionItem.find(id)
      expect(transaction.date).to eq(Time.parse(updated_date))
    end

    it 'succeeds for a successful description, value, and date together' do
      transaction = TransactionItem.find(id)
      expect(transaction.description).to eq(description)
      expect(transaction.value).to eq(value)
      expect(transaction.date).to eq(date)

      updated_description = 'Updated description'
      updated_value = 100.71
      updated_date = '2018-07-29'
      update_request(params: {
                       id: id,
                       description: updated_description,
                       value: updated_value,
                       date: updated_date
                     })

      assert_success
      transaction = TransactionItem.find(id)
      expect(transaction.description).to eq(updated_description)
      expect(transaction.value).to eq(updated_value)
      expect(transaction.date).to eq(Time.parse(updated_date))
    end

    it 'fails if transaction is not found' do
      update_request(params: { id: 1312, description: description, value: value, date: date })

      assert_response_failure(expected_message: 'Transaction not found')
    end
  end

  context 'deleting a transaction' do
    def delete_request(params:)
      post delete_transaction_item_path,
           params: params,
           headers: devise_request_headers
    end

    def assert_success
      assert_response_success(expected_message: 'Transaction successfully deleted')
    end

    let(:id) { 1 }
    let(:description) { 'Purchase' }
    let(:value) { -10.3 }
    let(:date) { Time.parse('March 17 2018') }

    it 'succeeds for valid description, value, and date params' do
      create(:transaction_item, id: id, description: description, value: value, date: date, user: user)

      delete_request(params: { id: 1 })

      transaction = TransactionItem.find_by(
        id: id,
        description: description,
        value: value.to_f,
        date: date
      )

      assert_success
      expect(transaction).to be_nil
    end

    it 'deletes only one transaction if multiple with the same description, value, and date' do
      initial_count = 3

      transaction_to_delete = create_list(
        :transaction_item,
        initial_count,
        description: description,
        value: value,
        date: date,
        user: user
      ).first

      delete_request(params: { id: transaction_to_delete.id })

      transactions = TransactionItem.where(
        description: description,
        value: value.to_f,
        date: date
      )

      assert_success
      expect(transactions.length).to eq(initial_count - 1)
    end

    it 'does not delete transaction items of other users' do
      another_user = create(:user, email: 'test2@example.com')
      create(:transaction_item, description: description, value: value, date: date, user: user)
      another_users_transaction = create(:transaction_item, description: description, value: value, date: date, user: another_user)
      before_delete = another_user.transaction_items.count

      delete_request(params: { id: another_users_transaction.id })

      assert_response_failure(expected_message: 'Transaction not found')
      after_delete = another_user.transaction_items.count
      expect(before_delete).to eq(after_delete)
    end
  end
end
