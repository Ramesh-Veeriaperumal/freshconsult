require_relative '../../unit_test_helper'
['account_test_helper.rb', 'users_test_helper.rb'].each { |file| require Rails.root.join('test', 'core', 'helpers', file) }
require Rails.root.join('test', 'models', 'helpers', 'subscription_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'omni_channels_test_helper.rb')
require 'sidekiq/testing'
require 'webmock/minitest'

Sidekiq::Testing.fake!

class OmniChannelUpgrade::FreshcallerAccountTest < ActionView::TestCase
  include AccountTestHelper
  include SubscriptionTestHelper
  include OmniChannelsTestHelper
  include CoreUsersTestHelper

  def setup
    super
    create_test_account
    OmniChannelUpgrade::SyncAgents.jobs.clear
    Freshid::V2::AccountDetailsUpdate.jobs.clear
    Billing::FreshcallerSubscriptionUpdate.jobs.clear
    org_domain = Faker::Internet.domain_name
    Account.any_instance.stubs(:omni_bundle_id).returns(Faker::Number.number(5))
    Account.any_instance.stubs(:organisation_domain).returns(org_domain)
    Account.any_instance.stubs(:organisation).returns(Organisation.new(organisation_id: Faker::Number.number(5), domain: org_domain))
    Freshid::V2::Models::Account.stubs(:find_by_domain).returns(Freshid::V2::Models::Account.new(id: Faker::Number.number(5)))
    user = @account.technicians.first
    org_admin_response = org_admin_users_response
    org_admin_response[:users][0][:email] = user.email
    Freshid::V2::Models::User.stubs(:account_users).returns(org_admin_response)
    Freshid::V2::Models::User.stubs(:find_by_email).returns(Freshid::V2::Models::User.new(id: Faker::Number.number(5), first_name: Faker::Name.first_name, email: user.email))
    Freshid::V2::Models::Organisation.stubs(:join_token).returns(Faker::Lorem.word)
  end

  def teardown
    Account.any_instance.unstub(:omni_bundle_id)
    Account.any_instance.unstub(:organisation_domain)
    Account.any_instance.unstub(:organisation)
    Freshid::V2::Models::Account.unstub(:find_by_domain)
    Freshid::V2::Models::User.unstub(:account_users)
    Freshid::V2::Models::User.unstub(:find_by_email)
    Freshid::V2::Models::Organisation.unstub(:join_token)
    super
  end

  def test_freshcaller_account_worker_fails_if_bundle_id_not_set
    Account.any_instance.stubs(:omni_bundle_id).returns(nil)
    error = assert_raises RuntimeError do
      OmniChannelUpgrade::FreshcallerAccount.new.perform(chargebee_response: { response: stub_update_params(@account.id) })
    end
    assert_equal error.message, 'Bundle id not present'
  ensure
    Account.any_instance.unstub(:omni_bundle_id)
  end

  def test_freshcaller_account_worker_fails_if_account_not_present_in_org
    Freshid::V2::Models::Account.stubs(:find_by_domain).returns(nil)
    error = assert_raises RuntimeError do
      OmniChannelUpgrade::FreshcallerAccount.new.perform(chargebee_response: { response: stub_update_params(@account.id) })
    end
    assert_equal error.message, 'Account not found in Freshid'
  ensure
    Freshid::V2::Models::Account.unstub(:find_by_domain)
  end

  def test_freshcaller_account_worker_fails_if_org_admin_not_present_in_org
    Freshid::V2::Models::User.stubs(:account_users).returns(nil)
    error = assert_raises RuntimeError do
      OmniChannelUpgrade::FreshcallerAccount.new.perform(chargebee_response: { response: stub_update_params(@account.id) })
    end
    assert_equal error.message, 'Organisation admin not found in Freshid'
  ensure
    Freshid::V2::Models::User.unstub(:account_users)
  end

  def test_freshcaller_account_worker_fails_if_org_admin_user_not_present_in_db
    Freshid::V2::Models::User.stubs(:account_users).returns(org_admin_users_response)
    error = assert_raises RuntimeError do
      OmniChannelUpgrade::FreshcallerAccount.new.perform(chargebee_response: { response: stub_update_params(@account.id) })
    end
    assert_equal error.message, 'Current user not found'
  ensure
    Freshid::V2::Models::User.unstub(:account_users)
  end

  def test_freshcaller_account_worker_fails_if_freshcaller_signup_fails
    stub_request(:post, OmniChannelBundleConfig['freshcaller_signup_url']).to_return(status: 500, body: {}.to_json, headers: {})
    error = assert_raises RuntimeError do
      OmniChannelUpgrade::FreshcallerAccount.new.perform(chargebee_response: { response: stub_update_params(@account.id) })
    end
    assert_equal error.message, 'Unsuccessful response on Freshcaller account signup'
  end

  def test_freshcaller_account_worker_succeeds_without_errors
    user = @account.technicians.first
    Account.any_instance.stubs(:freshfone_enabled?).returns(false)
    Freshcaller::Account.stubs(:create).returns(true)
    Agent.any_instance.stubs(:create_freshcaller_agent).returns(true)
    signup_response = freshcaller_bundle_signup_response(user.email)
    signup_response.stubs(:code).returns(200)
    HTTParty.stubs(:post).returns(signup_response)
    stub_request(:put, 'https://testbundlefreshcaller.freshfonehello.com/link_account').to_return(status: 200, body: {}.to_json, headers: {})
    agent_link_response = { sucess: true }
    agent_link_response.stubs(:body).returns({})
    agent_link_response.stubs(:code).returns(200)
    agent_link_response.stubs(:message).returns('Success')
    agent_link_response.stubs(:headers).returns({})
    HTTParty::Request.any_instance.stubs(:perform).returns(agent_link_response)
    assert_nothing_raised RuntimeError do
      OmniChannelUpgrade::FreshcallerAccount.new.perform(chargebee_response: { response: stub_update_params(@account.id) })
    end
    assert_equal OmniChannelUpgrade::SyncAgents.jobs.size, 1
    assert_equal Freshid::V2::AccountDetailsUpdate.jobs.size, 1
    assert_equal Billing::FreshcallerSubscriptionUpdate.jobs.size, 1
  ensure
    Account.any_instance.unstub(:freshfone_enabled?)
    Freshcaller::Account.unstub(:create)
    Agent.any_instance.unstub(:create_freshcaller_agent)
    HTTParty.unstub(:post)
    HTTParty::Request.any_instance.unstub(:perform)
  end

  private

    def freshcaller_bundle_signup_response(email)
      {
        'product_signup_response' => {
          'account' => {
            'id': Faker::Number.number(5),
            'domain' => 'testbundlefreshcaller.freshfonehello.com',
            'name' => 'testbundlefreshcaller'
          },
          'misc' => {
            'user' => {
              'freshcaller_account_admin_id' => Faker::Number.number(5),
              'freshcaller_account_admin_email' => email
            }
          },
          'redirect_url' => 'https://testbundlefreshcaller.freshfonehello.com/signup_complete/testdummy'
        }
      }
    end
end
