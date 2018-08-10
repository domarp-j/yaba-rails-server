# Convert CSV w/ expense data into transaction & tag model instances

# CSV Format
# date,description,value,tags
# January 1 2018,groceries,-20.3,groceries supplies
# January 2 2018,paycheck,500,paycheck work

# Execute this script by running `rails runner __File__`
# `rails runner` provides access to Rails models within lib/

require 'csv'
require_relative './converter_utilities.rb'

class CsvToDbConverter
  extend ConverterUtilities

  class << self
    def execute
      return unless check_for_required_args
      user = fetch_user(option_value('--user'), option_value('--pass'))
      return unless user && csv_exists?(option_value('--csv'))
      populate_database(user, option_value('--csv'))
    end

    private

    # Add transactions for user using CSV
    def populate_database(user, csv_location)
      CSV.read(csv_location, headers: true).each do |row|
        puts "Migrating record from CSV to yaba: #{row}"

        transaction = user.transaction_items.create(
          description: row[1],
          value: row[2].to_f,
          date: Time.parse(row[0])
        )

        add_tag(user, transaction, tag_names: row[3])
      end
    end

    # Add tags for user
    def add_tag(user, transaction, tag_names: '')
      tag_names.split(/\s+/).each do |tag_name|
        tag = user.tags.find_or_create_by(name: tag_name)
        TagTransaction.create(
          transaction_item_id: transaction.id,
          tag_id: tag.id
        )
      end
    end

    # Check that CSV exists
    def csv_exists?(csv_file)
      return true if File.exist?(csv_file)
      puts 'Error: could not find CSV file'
    end
  end
end

CsvToDbConverter.execute
