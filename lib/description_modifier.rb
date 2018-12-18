# Add tags to transaction description

# Before
# "Chipotle"

# After (tags added with #'s in front)
# "Chipotle #eating-out #fast-food"

# Execute this script by running `rails runner __File__`
# `rails runner` provides access to Rails models within lib/

require_relative './shared/utilities.rb'

class DescriptionModifier
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
      update_descriptions(user)
    end

    private

    # Fetch option
    def option(value)
      option_value(value, OPTIONS)
    end

    # Update descriptions with tags
    def update_descriptions(user)
      user.transaction_items.each do |trans|
        desc = trans.description
        trans.tags.each do |tag|
          desc += " ##{tag.name}"
        end
        trans.description = desc
        trans.save!
      end
    end
  end
end

DescriptionModifier.execute
