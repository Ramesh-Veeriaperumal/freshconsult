ENV["RAILS_ENV"] = "test"

require_relative "helpers/test_files.rb"

class ActionController::TestCase
  def setup
    activate_authlogic
    get_agent
    @account.make_current
    create_session
    set_request_params
  end

  self.use_transactional_fixtures = false
  fixtures :all
end

class ActionDispatch::IntegrationTest
  def setup
    get_agent
    set_request_headers
  end

  self.use_transactional_fixtures = false
  fixtures :all
end
