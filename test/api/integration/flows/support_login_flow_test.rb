# frozen_string_literal:true

require_relative '../../test_helper'

class SupportLoginFlowTest < ActionDispatch::IntegrationTest
  include UsersHelper
  include Redis::RedisKeys
  include Redis::OthersRedis

  def setup
    super
    @account = Account.first || create_new_account
    @account.make_current
  end

  def teardown
    Account.reset_current_account
    super
  end

  def test_support_login_when_session_timed_out_for_customer
    user_params = { name: Faker::Name.name, email: Faker::Internet.email, helpdesk_agent: 0 }
    user = add_new_user(@account, user_params)
    user.password = 'test'
    user.save
    user.make_current
    @account.launch(:idle_session_timeout)
    @account.account_additional_settings_from_cache.additional_settings[:idle_session_timeout] = 5
    @account.save
    Support::LoginController.any_instance.stubs(:session_timeout_allowed?).returns(true)
    UserSession.any_instance.stubs(:record).returns(user)
    post '/support/login', user_session: { email: user.email, password: 'test', remember_me: '0' }
    sleep 10
    post '/support/login', user_session: { email: user.email, password: 'test', remember_me: '0' }
    assert_equal I18n.t(:'flash.general.need_login'), flash[:notice]
  ensure
    @account.make_current
    @account.rollback(:idle_session_timeout)
    user.destroy
    Support::LoginController.any_instance.unstub(:session_timeout_allowed?)
    UserSession.any_instance.unstub(:record)
  end
end
