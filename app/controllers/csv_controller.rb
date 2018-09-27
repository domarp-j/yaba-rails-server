class TransactionItemsCsvController < ApplicationController
  before_action :authenticate_user!

  # Generate a CSV with all of the current user's transactions
  def index

  end

  # Upload a CSV with transactions for the current user
  def create
  end
end
