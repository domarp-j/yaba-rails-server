require 'csv'

class CsvController < ApplicationController
  before_action :authenticate_user!

  # Generate a CSV with all of the current user's transactions
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

  # TODO NOW: Use DbToCsvConverter
  def generate_transactions_csv
    CSV.generate do |csv|
      csv << %w[date description value tags]

      current_user.transaction_items.order(:date).limit(5).each do |transaction|
        t = {
          date: transaction.date.strftime('%B %d %Y'),
          description: transaction.description,
          value: transaction.value,
          tags: transaction.tags.map(&:name).join(' ')
        }
        csv << [t[:date], "'#{t[:description]}'", t[:value], t[:tags]]
      end
    end
  end
end
