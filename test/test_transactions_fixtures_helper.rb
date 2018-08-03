ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'

class ActionView::TestCase
  fixtures :all
  self.use_transactional_fixtures = false
  # Add more helper methods to be used by all tests here...
end