# Share code between the CSV to DB converter, and vice versa

module ConverterUtilities
  OPTIONS = {
    '--user' => "yaba user's email",
    '--pass' => "yaba user's password",
    '--csv' => 'location of expense data CSV'
  }.freeze

  private

  # Display error messages about missing options, if needed
  def check_for_required_args
    error_messages = collect_errors
    error_messages.each { |em| puts em }
    error_messages.empty?
  end

  # Collect error messages, if needed
  def collect_errors
    error_messages = []

    OPTIONS.each do |option, purpose|
      error_messages << "Missing option #{option}: #{purpose}" unless option_value(option)
    end

    error_messages
  end

  # Get value for a shell-provided option
  def option_value(opt)
    opt_index = ARGV.index(opt)
    return unless opt_index

    option_val = ARGV[opt_index + 1]
    return unless option_val && !OPTIONS.keys.include?(option_val)

    option_val
  end

  # Get user using provided email & password
  def fetch_user(user_email, user_pass)
    user = User.find_for_authentication(email: user_email)
    return user if user && user.valid_password?(user_pass)
    puts 'Error: an invalid email or password was provided'
  end
end
