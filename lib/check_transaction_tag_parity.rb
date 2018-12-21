# Ensure that there is parity between a transaction's description and tags
# For every tag that a transaction owns, there should be a hash-tagged word
# containing the name of the tag in the description

# Execute this script by running `rails runner __File__`
# `rails runner` provides access to Rails models within lib/

require_relative './shared/utilities.rb'

class CheckTransactionTagParity
  extend ConverterUtilities

  OPTIONS = {
    '--user' => "yaba user's email",
    '--pass' => "yaba user's password"
  }.freeze

  class << self
    def execute
      return unless check_for_required_args(OPTIONS)
      user = fetch_user(option('--user'), option('--pass'))
      return unless user
      check_transactions(user)
    end

    private

    # Fetch option
    def option(value)
      option_value(value, OPTIONS)
    end

    # Check transactions & make sure they have the correct description
    # based on their tags
    def check_transactions(user)
      puts 'Checking transactions...'

      faulty_transactions = []

      user.transaction_items.each do |trans|
        tags = fetch_tags(trans)
        tags_in_desc = pull_tags_from_desc(trans)
        faulty_transactions << trans if tags != tags_in_desc
      end

      if !faulty_transactions.empty?
        puts 'Faulty transactions found!'
        puts "See transactions with IDs: #{faulty_transactions.map(&:id)}"
      else
        puts 'All transactions good!'
      end
    end

    # Fetch tags for transaction & sort
    def fetch_tags(trans)
      trans.tags.map { |tag| tag.name.downcase }.sort
    end

    # Fetch tags from transaction description
    def pull_tags_from_desc(trans)
      trans.description.scan(/#([^\s]*)/).flatten.map(&:downcase).sort
    end
  end
end

CheckTransactionTagParity.execute
