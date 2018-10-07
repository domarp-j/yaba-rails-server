require 'csv'

class CsvController < ApplicationController
  before_action :authenticate_user!

  # Generate a CSV with all of the current user's transactions
  # TODO: Add tests
  def index
    respond_to do |format|
      format.csv do
        send_data(
          generate_transactions_csv,
          filename: 'transactions.csv'
        )
      end
    end
  end

  private

  # TODO: Use DbToCsvConverter
  def generate_transactions_csv
    CSV.generate do |csv|
      csv << %w[date description value tags]

      TransactionItem
        .includes(:tag_transactions, :tags)
        .where(user: current_user)
        .order(:date)
        .each do |transaction|
          csv << [
            transaction.date.strftime('%B %d %Y'),
            "'#{transaction.description}'",
            transaction.value,
            transaction.tags.map(&:name).join(' ')
          ]
        end
    end
  end
end
