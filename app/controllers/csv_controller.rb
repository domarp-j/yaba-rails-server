class TransactionItemsCsvController < ApplicationController
  before_action :authenticate_user!

  # Generate a CSV with all of the current user's transactions
  def index
    respond_to do |format|
      format.csv do
        send_data(
          generate_csv,
          filename: 'transactions.csv'
        )
      end
    end
  end

  # Upload a CSV with transactions for the current user
  def create
  end

  private

  def generate_csv
    CSV.generate do |csv|
      DbToCsvConverter.populate_csv(csv, user: current_user),
    end
  end
end
