require 'csv'
require_relative '../../lib/csv_tools/db_to_csv_converter.rb'

class CsvController < ApplicationController
  before_action :authenticate_user!

  # Generate a CSV with all of the current user's transactions
  def index
    send_data(
      generate_transactions_csv,
      filename: 'transactions.csv'
    )
  end

  # Upload a CSV with transactions for the current user
  def create
  end

  private

  def generate_transactions_csv
    CSV.generate do |csv|
      DbToCsvConverter.populate_csv(csv, user: current_user)
    end
  end
end
