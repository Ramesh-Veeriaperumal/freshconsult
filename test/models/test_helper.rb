require_relative 'helpers/test_files.rb'

class ActiveSupport::TestCase
  def setup
    create_test_account
    @account = Account.first
    @agent = get_admin
  end

  self.use_transactional_fixtures = false
  fixtures :all 
end