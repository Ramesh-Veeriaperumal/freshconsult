ENV['RAILS_ENV'] ||= 'test'

require_relative 'helpers/simple_cov_setup'
require_relative 'api/test_helper'
require 'rails/test_help'

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all
  self.use_transactional_fixtures = false
  # Add more helper methods to be used by all tests here...
end

# Faker:1.4.3 sets this to true.
# To ensure consistency in development, staging, production resetting `enforce_available_locales` variable to false
I18n.enforce_available_locales = false
