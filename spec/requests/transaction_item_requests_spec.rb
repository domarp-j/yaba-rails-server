require 'rails_helper'

RSpec.describe 'transaction items requests:', type: :request do
  limit_default = TransactionItem::DEFAULT_LIMIT

  let(:user) { create(:user, email: 'test1@example.com') }

  before do
    sign_in user
  end

  context 'fetching transactions for the signed-in user' do
    it "returns all of the user's transactions if (s)he has less than #{limit_default} items" do
      create_list(:transaction_item, limit_default - 1, :purchase, user: user)

      get transaction_items_path, headers: devise_request_headers
      actual = JSON.parse(response.body)

      expect(response.success?).to be(true)
      expect(actual['content'].length).to eq(limit_default - 1)
    end

    it "returns just #{limit_default} transactions if (s)he has more than #{limit_default} transactions" do
      create_list(:transaction_item, limit_default + 1, :purchase, user: user)

      get transaction_items_path, headers: devise_request_headers
      actual = JSON.parse(response.body)

      expect(response.success?).to be(true)
      expect(actual['content'].length).to eq(limit_default)
    end

    it 'returns a specific number of the user\'s latest transaction items if limit is given as a parameter' do
      create_list(:transaction_item, 10, :purchase, :two_weeks_ago, user: user)
      create_list(:transaction_item, 5, :purchase, :one_week_ago, user: user)

      get transaction_items_path, params: { limit: 5 }, headers: devise_request_headers
      actual = JSON.parse(response.body)

      expect(response.success?).to be(true)
      expect(actual['content'].length).to eq(5)
      actual['content'].each do |transaction|
        expect(Time.parse(transaction['date'])).to be_within(1.hour).of(1.week.ago)
      end
    end

    it 'returns transactions with an offset if page is given as a parameter' do
      create_list(:transaction_item, limit_default, :purchase, :two_weeks_ago, user: user)
      create_list(:transaction_item, limit_default, :purchase, :one_week_ago, user: user)

      get transaction_items_path, params: { page: 1 }, headers: devise_request_headers
      actual = JSON.parse(response.body)

      expect(response.success?).to be(true)
      expect(actual['content'].length).to eq(limit_default)
      actual['content'].each do |transaction|
        expect(Time.parse(transaction['date'])).to be_within(1.hour).of(2.week.ago)
      end
    end

    it 'returns transactions with a limit and offset if limit & page are given as parameters' do
      create_list(:transaction_item, 10, :purchase, :two_weeks_ago, user: user)
      create_list(:transaction_item, 5, :purchase, :one_week_ago, user: user)

      get transaction_items_path, params: { limit: 6, page: 1 }, headers: devise_request_headers
      actual = JSON.parse(response.body)

      transaction = actual['content'][0]

      expect(response.success?).to be(true)
      expect(Time.parse(transaction['date'])).to be_within(1.hour).of(2.week.ago)
    end

    it 'does not return transaction items for other users' do
      another_user = create(:user, email: 'test2@example.com')
      create_list(:transaction_item, 5, :large_income, user: another_user)

      get transaction_items_path, headers: devise_request_headers
      actual = JSON.parse(response.body)

      expect(response.success?).to be(true)
      expect(actual['content'].length).to eq(0)
    end
  end

  context 'adding a new transaction for the signed-in user' do
    it 'succeeds for a valid description, value, and date' do
      description = 'Some purchase'
      value = '-12.3'
      date = '2018-07-29'

      post add_transaction_item_path,
           params: { description: description, value: value, date: date },
           headers: devise_request_headers

      added_transaction = TransactionItem.find_by(
        description: description,
        value: value.to_f,
        date: Time.parse(date)
      )

      json_response = JSON.parse(response.body)['content']

      expect(response.success?).to be(true)
      expect(json_response['id']).to eq(added_transaction.id)
      expect(json_response['description']).to eq(description)
      expect(json_response['value']).to eq(value.to_f)
      expect(Time.parse(json_response['date'])).to eq(Time.parse(date))
      expect(added_transaction).not_to be_nil, 'Expected to find the newly-added transaction'
    end
  end

  context 'updating a transaction for a signed-in user' do
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
      post update_transaction_item_path,
           params: { id: id, description: updated_description },
           headers: devise_request_headers

      transaction = TransactionItem.find(id)
      expect(transaction.description).to eq(updated_description)
    end

    it 'succeeds for valid value' do
      transaction = TransactionItem.find(id)
      expect(transaction.value).to eq(value)

      updated_value = 100.71
      post update_transaction_item_path,
           params: { id: id, value: updated_value },
           headers: devise_request_headers

      transaction = TransactionItem.find(id)
      expect(transaction.value).to eq(updated_value)
    end

    it 'succeeds for valid date' do
      transaction = TransactionItem.find(id)
      expect(transaction.date).to eq(date)

      updated_date = '2018-07-29'
      post update_transaction_item_path,
           params: { id: id, date: updated_date },
           headers: devise_request_headers

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
      post update_transaction_item_path,
           params: { id: id, description: updated_description, value: updated_value, date: updated_date },
           headers: devise_request_headers

      transaction = TransactionItem.find(id)
      expect(transaction.description).to eq(updated_description)
      expect(transaction.value).to eq(updated_value)
      expect(transaction.date).to eq(Time.parse(updated_date))
    end
  end

  context 'deleting a transaction for a signed-in user' do
    let(:id) { 1 }
    let(:description) { 'Purchase' }
    let(:value) { -10.3 }
    let(:date) { Time.parse('March 17 2018') }

    it 'succeeds for valid description, value, and date params' do
      create(:transaction_item, id: id, description: description, value: value, date: date, user: user)

      post delete_transaction_item_path,
           params: { id: 1 },
           headers: devise_request_headers

      transaction = TransactionItem.find_by(
        id: id,
        description: description,
        value: value.to_f,
        date: date
      )

      expect(response.success?).to be(true)
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

      post delete_transaction_item_path,
           params: { id: transaction_to_delete.id },
           headers: devise_request_headers

      transactions = TransactionItem.where(
        description: description,
        value: value.to_f,
        date: date
      )

      expect(response.success?).to be(true)
      expect(transactions.length).to eq(initial_count - 1)
    end

    it 'does not delete transaction items of other users' do
      another_user = create(:user, email: 'test2@example.com')

      create(:transaction_item, description: description, value: value, date: date, user: user)
      another_users_transaction = create(:transaction_item, description: description, value: value, date: date, user: another_user)

      before_delete = another_user.transaction_items.count

      post delete_transaction_item_path,
           params: { id: another_users_transaction.id },
           headers: devise_request_headers

      after_delete = another_user.transaction_items.count

      expect(response.success?).to be(false)
      expect(before_delete).to eq(after_delete)
    end
  end
end
