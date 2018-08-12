class HealthCheckController < ApplicationController
  def new
    render json: {
      success: true,
      message: 'You have successfully hit the Yaba API!'
    }
  end
end
