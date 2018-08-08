require_relative 'helpers/test_files.rb'

class ActiveSupport::TestCase
  def setup
    $redis_others.set('NEW_SIGNUP_ENABLED', 1)
    create_test_account
    @account = Account.first
    @account.reputation = 1
    @account.save
    @agent = get_admin

    #Stub all memcache calls
    Dalli::Client.any_instance.stubs(:get).returns(nil)
    Dalli::Client.any_instance.stubs(:delete).returns(true)
    Dalli::Client.any_instance.stubs(:set).returns(true)
  end

  self.use_transactional_fixtures = false
  fixtures :all
end
