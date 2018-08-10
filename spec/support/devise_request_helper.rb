require 'warden'

# Helper for using devise_token_auth gem in request tests
module DeviseRequestHelper
  # Sign in user and extract header values from response
  # Controller actions will use these header values to submit requests
  def sign_in(user)
    post user_session_path, params: {
      email: user.email,
      password: user.password
    }

    @headers = {
      'access-token' => response.headers['access-token'],
      'client' => response.headers['client'],
      'expiry' => response.headers['expiry'],
      'uid' => user.email
    }
  end

  # Request headers for all requests that require Devise authentication
  def devise_request_headers
    @headers
  end
end
