# frozen_string_literal: true

require_relative '../../../../api/test_helper'
require Rails.root.join('spec', 'support', 'user_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require 'sidekiq/testing'
class Integrations::Marketplace::SignupControllerTest < ActionController::TestCase
  include UsersHelper
  include AccountTestHelper

  def setup
    super
    stub_signup_calls
  end

  def teardown
    super
    unstub_signup_calls
  end

  def stub_signup_calls
    Signup.any_instance.stubs(:save).returns(true)
    AccountInfoToDynamo.stubs(:perform_async).returns(true)
    Account.any_instance.stubs(:mark_new_account_setup_and_save).returns(true)
    Account.any_instance.stubs(:launched?).returns(true)
    Account.any_instance.stubs(:anonymous_account?).returns(false)
    Account.any_instance.stubs(:fluffy_email_signup_enabled?).returns(false)
    User.any_instance.stubs(:deliver_admin_activation).returns(true)
    User.any_instance.stubs(:perishable_token).returns(Faker::Number.number(5))
    User.any_instance.stubs(:reset_perishable_token!).returns(true)
  end

  def unstub_signup_calls
    Signup.any_instance.unstub(:save)
    AccountInfoToDynamo.unstub(:perform_async)
    Account.any_instance.unstub(:mark_new_account_setup_and_save)
    Account.any_instance.unstub(:launched?)
    Account.any_instance.unstub(:anonymous_account?)
    Account.any_instance.unstub(:fluffy_email_signup_enabled?)
    User.any_instance.unstub(:deliver_admin_activation)
    User.any_instance.unstub(:perishable_token)
    User.any_instance.unstub(:reset_perishable_token!)
  end

  def test_create_account
    Signup.any_instance.unstub(:save)
    Signup.any_instance.stubs(:freshid_v2_signup_allowed?).returns(true)
    Account.any_instance.stubs(:create_freshid_v2_account).returns(true)
    Signup.any_instance.expects(:create_freshid_v2_org_and_account).once
    account_name = Faker::Lorem.word
    user_email = Faker::Internet.email
    user_name = Faker::Name.name
    remote_id = "#{Faker::Lorem.word}.org.ya"
    get :create_account, call_back: '', user: { email: user_email, remote_id: remote_id, name: user_name, phone: '' }, utc_offset: '', account: { google_domain: '', name: account_name, domain: Faker::Lorem.word }, request_params: { app_name: 'google', operation: 'onboarding_google', email_not_reqd: '' }, session_json: '', first_referrer: '', first_landing_url: '', first_search_engine: '', first_search_query: ''
    assert_response 302
  ensure
    Signup.any_instance.unstub(:freshid_v2_signup_allowed?)
    Account.any_instance.unstub(:create_freshid_v2_account)
  end
end
