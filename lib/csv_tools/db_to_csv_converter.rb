# Convert a user's transactions, with tags, into a CSV of expense data

# CSV Format
# date,description,value,tags
# January 1 2018,groceries,-20.3,groceries supplies
# January 2 2018,paycheck,500,paycheck work

# Execute this script by running `rails runner __File__`
# `rails runner` provides access to Rails models within lib/

require 'csv'
require_relative './converter_utilities.rb'

class DbToCsvConverter
  extend ConverterUtilities

  class << self
    def execute
      return unless check_for_required_args
      user = fetch_user(option_value('--user'), option_value('--pass'))
      return unless user
      extract_expense_data(user, option_value('--csv'))
    end

    def populate_csv(csv, user:, logging: false)
      csv << %w[date description value tags]

      TransactionItem.where(user: user).order(:date).each do |transaction|
        t = fetch_transaction_details(transaction)
        puts "Migrating record from yaba to CSV: #{t}" if logging
        csv << [t[:date], "'#{t[:description]}'", t[:value], t[:tags]]
      end
    end

    private

    # Take user transaction data from database and seed CSV
    def extract_expense_data(user, csv_location)
      CSV.open(csv_location, 'wb') do |csv|
        populate_csv(csv, user: user, logging: true)
      end
    end

    # Collect all details for a transaction, cleaning up output as needed
    def fetch_transaction_details(transaction)
      {
        date: transaction.date.strftime('%B %d %Y'),
        description: transaction.description,
        value: transaction.value,
        tags: transaction.tags.map(&:name).join(' ')
      }
    end
  end
end

DbToCsvConverter.execute
