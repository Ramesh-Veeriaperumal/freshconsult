require_relative '../../unit_test_helper'
['account_test_helper.rb', 'users_test_helper.rb'].each { |file| require Rails.root.join('test', 'core', 'helpers', file) }
require Rails.root.join('test', 'models', 'helpers', 'subscription_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'omni_channels_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'billing_test_helper.rb')
require 'sidekiq/testing'
require 'webmock/minitest'

Sidekiq::Testing.fake!
class OmniChannelUpgrade::FreshchatAccountTest < ActionView::TestCase
  include OmniChannel::Constants
  include AccountTestHelper
  include SubscriptionTestHelper
  include OmniChannelsTestHelper
  include CoreUsersTestHelper
  include BillingTestHelper

  def setup
    super
    OmniChannelUpgrade::SyncAgents.jobs.clear
    OmniChannelUpgrade::LinkAccount.jobs.clear
    Freshid::V2::AccountDetailsUpdate.jobs.clear
    Billing::FreshchatSubscriptionUpdate.jobs.clear
    create_test_account
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

  def test_freshchat_account_worker_fails_if_bundle_id_not_set
    Account.any_instance.stubs(:omni_bundle_id).returns(nil)
    error = assert_raises RuntimeError do
      OmniChannelUpgrade::FreshchatAccount.new.perform(chargebee_response: { response: stub_update_params(@account.id) }, type: PRODUCT_OMNI_UPGRADE)
    end
    assert_equal error.message, 'Bundle id not present'
  ensure
    Account.any_instance.unstub(:omni_bundle_id)
  end

  def test_freshchat_account_worker_fails_if_freshchat_signup_fails
    stub_request(:post, OmniChannelBundleConfig['freshchat_signup_url']).to_return(status: 500, body: {}.to_json, headers: {})
    error = assert_raises RuntimeError do
      OmniChannelUpgrade::FreshchatAccount.new.perform(chargebee_response: { response: stub_update_params(@account.id) }, type: PRODUCT_OMNI_UPGRADE)
    end
    assert_equal error.message, 'Unsuccessful response on Freshchat account signup'
  end

  def test_freshchat_account_worker_succeeds_without_errors
    fc_account_object = Freshchat::Account.new(app_id: 'app-bundle-id')
    Account.any_instance.stubs(:create_freshchat_account).returns(fc_account_object)
    Account.any_instance.stubs(:freshchat_account).returns(fc_account_object)
    Account.any_instance.stubs(:omni_chat_agent_enabled?).returns(true)
    Agent.any_instance.stubs(:update_attribute).returns(true)
    signup_response = freshchat_bundle_signup_response
    signup_response.stubs(:code).returns(200)
    HTTParty.stubs(:post).returns(signup_response)
    stub_request(:put, 'https://api.freshchat.com/v2/omnichannel-integration/app-bundle-id').to_return(status: 200, body: {}.to_json, headers: {})
    assert_nothing_raised RuntimeError do
      OmniChannelUpgrade::FreshchatAccount.new.perform(chargebee_response: { response: stub_update_params(@account.id) }, type: PRODUCT_OMNI_UPGRADE)
    end
    assert_equal OmniChannelUpgrade::SyncAgents.jobs.size, 1
    assert_equal Freshid::V2::AccountDetailsUpdate.jobs.size, 1
    assert_equal Billing::FreshchatSubscriptionUpdate.jobs.size, 1
  ensure
    Account.any_instance.unstub(:create_freshchat_account)
    Account.any_instance.unstub(:freshchat_account)
    Account.any_instance.unstub(:omni_chat_agent_enabled?)
    Agent.any_instance.unstub(:update_attribute)
    HTTParty.unstub(:post)
  end

  def test_chargebee_omni_upgrade_freshchat_account_worker_succeeds_without_errors
    Account.any_instance.stubs(:freshfone_enabled?).returns(false)
    fc_account_object = Freshchat::Account.new(app_id: 'app-bundle-id')
    Account.any_instance.stubs(:freshchat_account).returns(fc_account_object)
    Account.any_instance.stubs(:omni_chat_agent_enabled?).returns(true)
    Agent.any_instance.stubs(:update_attribute).returns(true)
    move_to_bundle_response = {}
    move_to_bundle_response.stubs(:body).returns(stub_move_to_bundle_response(true))
    move_to_bundle_response.stubs(:code).returns(200)
    HTTParty.stubs(:post).returns(move_to_bundle_response)
    stub_request(:put, 'https://api.freshchat.com/v2/omnichannel-integration/app-bundle-id').to_return(status: 200, body: {}.to_json, headers: {})
    assert_nothing_raised RuntimeError do
      OmniChannelUpgrade::FreshchatAccount.new.perform(chargebee_response: omni_upgrade_chargebee_response, type: CHARGEBEE_OMNI_UPGRADE)
    end
    assert_equal OmniChannelUpgrade::SyncAgents.jobs.size, 1
    assert_equal OmniChannelUpgrade::LinkAccount.jobs.size, 1
    assert_equal Freshid::V2::AccountDetailsUpdate.jobs.size, 1
    assert_equal Billing::FreshchatSubscriptionUpdate.jobs.size, 1
  ensure
    Account.any_instance.unstub(:freshfone_enabled?)
    Account.any_instance.unstub(:freshchat_account)
    Account.any_instance.unstub(:omni_chat_agent_enabled?)
    Agent.any_instance.unstub(:update_attribute)
    HTTParty.unstub(:post)
  end

  private

    def freshchat_bundle_signup_response
      {
        'product_signup_response' => {
          'account' => {
            'domain': 'testbundlefreshchat.freshpori.com'
          },
          'misc' => {
            'userInfoList' => [{
              'appId' => 'app-bundle-id',
              'webchatId' => 'webchat-bundle-id'
            }]
          }
        }
      }
    end

    def stub_move_to_bundle_response(success)
      {
        'success' => success
      }
    end
end
