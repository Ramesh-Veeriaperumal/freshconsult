# frozen_string_literal: true

require_relative '../../../api/test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'billing_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')
require Rails.root.join('test', 'models', 'helpers', 'subscription_test_helper.rb')

class Fdadmin::BillingControllerTest < ActionController::TestCase
  include Billing::BillingHelper
  include AccountTestHelper
  include BillingTestHelper
  include SubscriptionTestHelper
  include CoreUsersTestHelper

  def setup
    super
    before_all
  end

  def before_all
    @account.freshcaller_account&.destroy
    @account.freshchat_account&.destroy
    @account.reload
  end

  def stub_fdadmin
    ShardMapping.stubs(:find).returns(ShardMapping.first)
    OpenSSL::HMAC.stubs(:hexdigest).returns('xyz')
    Fdadmin::DevopsMainController.stubs(:verify_signature).returns(nil)
    Fdadmin::DevopsMainController.stubs(:permit_internal_tools_ip).returns(nil)
    FreshopsSubdomains.stubs(:include?).returns(true)
    $redis_routes.stubs(:perform_redis_op).returns(true)
  end

  def unstub_fdadmin
    ShardMapping.unstub(:find)
    OpenSSL::HMAC.unstub(:hexdigest)
    Fdadmin::DevopsMainController.unstub(:verify_signature)
    Fdadmin::DevopsMainController.unstub(:permit_internal_tools_ip)
    FreshopsSubdomains.unstub(:include?)
    $redis_routes.unstub(:perform_redis_op)
  end

  def stub_subscription_settings(options = {})
    WebMock.allow_net_connect!
    Account.stubs(:current).returns(@account)
    update_params = stub_update_params(@account.id)
    update_params[:subscription].merge!(options[:addons]) if options[:addons]
    update_params[:subscription][:plan_id] = options[:plan_id] if options[:plan_id]
    update_params[:subscription][:status] = options[:status] if options[:status]
    chargebee_update = ChargeBee::Result.new(update_params)
    ChargeBee::Subscription.stubs(:retrieve).returns(chargebee_update)
    Digest::MD5.stubs(:hexdigest).returns('5c8231431eca2c61377371de706a52cc')
    @controller.request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials('freshdesk', 'freshdesk')
    ChargeBee::Subscription.any_instance.stubs(:plan_id).returns('forest_annual')
    Subscription.any_instance.stubs(:update_attributes).returns(true)
    Subscription.any_instance.stubs(:save).returns(true)
    AccountAdditionalSettings.any_instance.stubs(:set_payment_preference).returns(true)
    Subscription::UpdatePartnersSubscription.stubs(:perform_async).returns(true)
    Billing::Subscription.any_instance.stubs(:update_subscription).returns(true)
    stub_fdadmin
  end

  def unstub_subscription_settings
    Account.unstub(:current)
    ChargeBee::Subscription.unstub(:retrieve)
    Digest::MD5.unstub(:hexdigest)
    ChargeBee::Subscription.any_instance.unstub(:plan_id)
    Subscription.any_instance.unstub(:update_attributes)
    Subscription.any_instance.unstub(:save)
    AccountAdditionalSettings.any_instance.unstub(:set_payment_preference)
    Subscription::UpdatePartnersSubscription.unstub(:perform_async)
    Billing::Subscription.any_instance.unstub(:update_subscription)
    unstub_fdadmin
    WebMock.disable_net_connect!
  end

  def test_subscription_changed_event_chargebee_omni_upgrade_without_launchparty
    create_new_account('test1', 'test1@freshdesk.com')
    Account.stubs(:current).returns(@account.reload)
    stub_subscription_settings(plan_id: 'estate_omni_jan_20_monthly')
    Subscription.any_instance.unstub(:update_attributes)
    Subscription.any_instance.unstub(:save)
    @account.rollback(:chargebee_omni_upgrade)
    ChargeBee::Subscription.any_instance.unstub(:plan_id)
    ChargeBee::Subscription.any_instance.stubs(:status).returns('active')
    Subscription.any_instance.stubs(:first_time_paid_non_annual_plan?).returns(false)
    post :trigger, event_type: 'subscription_changed', content: omni_upgrade_event_content, digest: 'xyz', format: 'json'
    assert_response 200
    assert_equal @account.reload.plan_name.to_s, 'estate_omni_jan_20'
  ensure
    @account.destroy
    Account.unstub(:current)
    unstub_subscription_settings
    ChargeBee::Subscription.any_instance.unstub(:status)
    Subscription.any_instance.unstub(:first_time_paid_non_annual_plan?)
  end

  def test_subscription_changed_event_chargebee_omni_upgrade_with_launchparty
    old_plan_name = @account.plan_name.to_s
    stub_subscription_settings(plan_id: 'estate_omni_jan_20_monthly')
    @account.launch(:chargebee_omni_upgrade)
    ChargeBee::Subscription.any_instance.unstub(:plan_id)
    ChargeBee::Subscription.any_instance.stubs(:status).returns('active')
    post :trigger, event_type: 'subscription_changed', content: omni_upgrade_event_content, digest: 'xyz', format: 'json'
    assert_response 200
    assert_equal @account.reload.plan_name.to_s, old_plan_name
  ensure
    unstub_subscription_settings
    @account.rollback(:chargebee_omni_upgrade)
    ChargeBee::Subscription.any_instance.unstub(:status)
  end

  def test_subscription_changed_event_chargebee_omni_upgrade_with_launchparty_only_freshchat_integrated
    old_plan_name = @account.plan_name.to_s
    stub_subscription_settings(plan_id: 'estate_omni_jan_20_monthly')
    @account.launch(:chargebee_omni_upgrade)
    chargebee_omni_pre_requisites_setup(true, false)
    ChargeBee::Subscription.any_instance.unstub(:plan_id)
    ChargeBee::Subscription.any_instance.stubs(:status).returns('active')
    post :trigger, event_type: 'subscription_changed', content: omni_upgrade_event_content, digest: 'xyz', format: 'json'
    assert_response 200
    assert_equal @account.reload.plan_name.to_s, old_plan_name
  ensure
    unstub_subscription_settings
    @account.rollback(:chargebee_omni_upgrade)
    chargebee_omni_pre_requisites_teardown
    ChargeBee::Subscription.any_instance.unstub(:status)
  end

  def test_subscription_changed_event_chargebee_omni_upgrade_with_launchparty_only_freshcaller_integrated
    old_plan_name = @account.plan_name.to_s
    stub_subscription_settings(plan_id: 'estate_omni_jan_20_monthly')
    @account.launch(:chargebee_omni_upgrade)
    chargebee_omni_pre_requisites_setup(false, true)
    ChargeBee::Subscription.any_instance.unstub(:plan_id)
    ChargeBee::Subscription.any_instance.stubs(:status).returns('active')
    post :trigger, event_type: 'subscription_changed', content: omni_upgrade_event_content, digest: 'xyz', format: 'json'
    assert_response 200
    assert_equal @account.reload.plan_name.to_s, old_plan_name
  ensure
    unstub_subscription_settings
    @account.rollback(:chargebee_omni_upgrade)
    chargebee_omni_pre_requisites_teardown
    ChargeBee::Subscription.any_instance.unstub(:status)
  end

  def test_subscription_changed_event_chargebee_omni_upgrade_both_freshchat_and_freshcaller_integrated_but_freshchat_not_in_same_org
    old_plan_name = @account.plan_name.to_s
    stub_subscription_settings(plan_id: 'estate_omni_jan_20_monthly')
    @account.launch(:chargebee_omni_upgrade)
    chargebee_omni_pre_requisites_setup(true, true)
    org = create_organisation(12_345, @account.full_domain)
    create_organisation_account_mapping(org.id)
    metadata = { page_number: 1, page_size: 2, has_more: false }
    fcl_domain = @account.freshcaller_account.domain
    freshid_response = org_freshid_response(create_sample_account_details('localhost.freshpori.net', fcl_domain), metadata)
    Freshid::V2::Models::Account.stubs(:organisation_accounts).returns(freshid_response)
    ChargeBee::Subscription.any_instance.unstub(:plan_id)
    ChargeBee::Subscription.any_instance.stubs(:status).returns('active')
    post :trigger, event_type: 'subscription_changed', content: omni_upgrade_event_content, digest: 'xyz', format: 'json'
    assert_response 200
    assert_equal @account.reload.plan_name.to_s, old_plan_name
  ensure
    unstub_subscription_settings
    delete_organisation(org.id) if org
    @account.rollback(:chargebee_omni_upgrade)
    chargebee_omni_pre_requisites_teardown
    Freshid::V2::Models::Account.unstub(:organisation_accounts)
    ChargeBee::Subscription.any_instance.unstub(:status)
  end

  def test_subscription_changed_event_chargebee_omni_upgrade_both_freshchat_and_freshcaller_integrated_but_freshcaller_not_in_same_org
    old_plan_name = @account.plan_name.to_s
    stub_subscription_settings(plan_id: 'estate_omni_jan_20_monthly')
    @account.launch(:chargebee_omni_upgrade)
    chargebee_omni_pre_requisites_setup(true, true)
    org = create_organisation(12_345, @account.full_domain)
    create_organisation_account_mapping(org.id)
    metadata = { page_number: 1, page_size: 2, has_more: false }
    fch_domain = @account.freshchat_account.domain
    freshid_response = org_freshid_response(create_sample_account_details(fch_domain, 'localhost.freshcaller.net'), metadata)
    Freshid::V2::Models::Account.stubs(:organisation_accounts).returns(freshid_response)
    ChargeBee::Subscription.any_instance.unstub(:plan_id)
    ChargeBee::Subscription.any_instance.stubs(:status).returns('active')
    post :trigger, event_type: 'subscription_changed', content: omni_upgrade_event_content, digest: 'xyz', format: 'json'
    assert_response 200
    assert_equal @account.reload.plan_name.to_s, old_plan_name
  ensure
    unstub_subscription_settings
    delete_organisation(org.id) if org
    @account.rollback(:chargebee_omni_upgrade)
    chargebee_omni_pre_requisites_teardown
    Freshid::V2::Models::Account.unstub(:organisation_accounts)
    ChargeBee::Subscription.any_instance.unstub(:status)
  end

  def test_subscription_changed_event_chargebee_omni_upgrade_both_freshchat_and_freshcaller_integrated_in_same_org_but_freshdesk_agents_are_not_superset_of_freshchat_agents
    old_plan_name = @account.plan_name.to_s
    stub_subscription_settings(plan_id: 'estate_omni_jan_20_monthly')
    @account.launch(:chargebee_omni_upgrade)
    fch_agent_emails = ['sample@freshchat.com']
    chargebee_omni_pre_requisites_setup(true, true)
    org = create_organisation(12_345, @account.full_domain)
    create_organisation_account_mapping(org.id)
    metadata = { page_number: 1, page_size: 2, has_more: false }
    fch_domain = @account.freshchat_account.domain
    fcl_domain = @account.freshcaller_account.domain
    freshid_response = org_freshid_response(create_sample_account_details(fch_domain, fcl_domain), metadata)
    Freshid::V2::Models::Account.stubs(:organisation_accounts).returns(freshid_response)
    Faraday::Connection.any_instance.stubs(:get).returns(Faraday::Response.new(status: 200, body: sample_freshchat_agents_response(fch_agent_emails)))
    ChargeBee::Subscription.any_instance.unstub(:plan_id)
    ChargeBee::Subscription.any_instance.stubs(:status).returns('active')
    post :trigger, event_type: 'subscription_changed', content: omni_upgrade_event_content, digest: 'xyz', format: 'json'
    assert_response 200
    assert_equal @account.reload.plan_name.to_s, old_plan_name
  ensure
    unstub_subscription_settings
    delete_organisation(org.id) if org
    @account.rollback(:chargebee_omni_upgrade)
    chargebee_omni_pre_requisites_teardown
    Freshid::V2::Models::Account.unstub(:organisation_accounts)
    Faraday::Connection.any_instance.unstub(:get)
    ChargeBee::Subscription.any_instance.unstub(:status)
  end

  def test_subscription_changed_event_chargebee_omni_upgrade_both_freshchat_and_freshcaller_integrated_in_same_org_but_freshdesk_agents_are_not_superset_of_freshcaller_agents
    old_plan_name = @account.plan_name.to_s
    stub_subscription_settings(plan_id: 'estate_omni_jan_20_monthly')
    @account.launch(:chargebee_omni_upgrade)
    fch_agent = add_test_agent(@account)
    fch_agent_emails = [fch_agent.email]
    fcl_agent_emails = ['sample@freshcaller.com']
    chargebee_omni_pre_requisites_setup(true, true)
    org = create_organisation(12_345, @account.full_domain)
    create_organisation_account_mapping(org.id)
    metadata = { page_number: 1, page_size: 2, has_more: false }
    fch_domain = @account.freshchat_account.domain
    fcl_domain = @account.freshcaller_account.domain
    freshid_response = org_freshid_response(create_sample_account_details(fch_domain, fcl_domain), metadata)
    Freshid::V2::Models::Account.stubs(:organisation_accounts).returns(freshid_response)
    Faraday::Connection.any_instance.stubs(:get).returns(Faraday::Response.new(status: 200, body: sample_freshchat_agents_response(fch_agent_emails)))
    HTTParty::Request.any_instance.stubs(:perform).returns(sample_freshcaller_agents_response(fcl_agent_emails))
    ChargeBee::Subscription.any_instance.unstub(:plan_id)
    ChargeBee::Subscription.any_instance.stubs(:status).returns('active')
    post :trigger, event_type: 'subscription_changed', content: omni_upgrade_event_content, digest: 'xyz', format: 'json'
    assert_response 200
    assert_equal @account.reload.plan_name.to_s, old_plan_name
  ensure
    fch_agent&.destroy
    unstub_subscription_settings
    delete_organisation(org.id) if org
    @account.rollback(:chargebee_omni_upgrade)
    chargebee_omni_pre_requisites_teardown
    Freshid::V2::Models::Account.unstub(:organisation_accounts)
    Faraday::Connection.any_instance.unstub(:get)
    HTTParty::Request.any_instance.unstub(:perform)
    ChargeBee::Subscription.any_instance.unstub(:status)
  end

  def test_subscription_changed_event_chargebee_omni_upgrade_getting_org_account_raises_error
    old_plan_name = @account.plan_name.to_s
    stub_subscription_settings(plan_id: 'estate_omni_jan_20_monthly')
    @account.launch(:chargebee_omni_upgrade)
    chargebee_omni_pre_requisites_setup(true, true)
    Freshid::V2::Models::Account.stubs(:organisation_accounts).raises(StandardError)
    post :trigger, event_type: 'subscription_changed', content: omni_upgrade_event_content, digest: 'xyz', format: 'json'
    assert_response 200
    assert_equal @account.reload.plan_name.to_s, old_plan_name
  ensure
    unstub_subscription_settings
    @account.rollback(:chargebee_omni_upgrade)
    chargebee_omni_pre_requisites_teardown
    Freshid::V2::Models::Account.unstub(:organisation_accounts)
  end

  def test_subscription_changed_event_chargebee_omni_upgrade_both_freshchat_and_freshcaller_integrated_in_same_org_with_freshdesk_agents_are_superset_of_freshcaller_and_freshchat_agents
    create_new_account('test2', 'test2@freshdesk.com')
    Account.stubs(:current).returns(@account.reload)
    stub_subscription_settings(plan_id: 'estate_omni_jan_20_monthly')
    Subscription.any_instance.unstub(:update_attributes)
    Subscription.any_instance.unstub(:save)
    @account.launch(:chargebee_omni_upgrade)
    fch_agent = add_test_agent(@account)
    fch_agent_emails = [fch_agent.email]
    fcl_agent1 = add_test_agent(@account)
    fcl_agent2 = add_test_agent(@account)
    fcl_agent_emails = [fcl_agent1.email, fcl_agent2.email]
    chargebee_omni_pre_requisites_setup(true, true)
    org = create_organisation(12_345, @account.full_domain)
    create_organisation_account_mapping(org.id)
    metadata = { page_number: 10, page_size: 2, has_more: false }
    fch_domain = @account.freshchat_account.domain
    fcl_domain = @account.freshcaller_account.domain
    freshid_response = org_freshid_response(create_sample_account_details(fch_domain, fcl_domain), metadata)
    Freshid::V2::Models::Account.stubs(:organisation_accounts).returns(freshid_response)
    Faraday::Connection.any_instance.stubs(:get).returns(Faraday::Response.new(status: 200, body: sample_freshchat_agents_response(fch_agent_emails)))
    HTTParty::Request.any_instance.stubs(:perform).returns(sample_freshcaller_agents_response(fcl_agent_emails))
    ChargeBee::Subscription.any_instance.unstub(:plan_id)
    ChargeBee::Subscription.any_instance.stubs(:status).returns('active')
    Subscription.any_instance.stubs(:first_time_paid_non_annual_plan?).returns(false)
    post :trigger, event_type: 'subscription_changed', content: omni_upgrade_event_content, digest: 'xyz', format: 'json'
    assert_response 200
    assert_equal @account.reload.plan_name.to_s, 'estate_omni_jan_20'
  ensure
    fch_agent&.destroy
    fcl_agent1&.destroy
    fcl_agent2&.destroy
    delete_organisation(org.id) if org
    @account.rollback(:chargebee_omni_upgrade)
    chargebee_omni_pre_requisites_teardown
    @account.destroy
    Account.unstub(:current)
    unstub_subscription_settings
    Freshid::V2::Models::Account.unstub(:organisation_accounts)
    Faraday::Connection.any_instance.unstub(:get)
    HTTParty::Request.any_instance.unstub(:perform)
    ChargeBee::Subscription.any_instance.unstub(:status)
    Subscription.any_instance.unstub(:first_time_paid_non_annual_plan?)
  end
end
