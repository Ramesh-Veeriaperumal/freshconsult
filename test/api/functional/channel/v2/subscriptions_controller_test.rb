require_relative '../../../../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'models', 'helpers', 'subscription_test_helper.rb')

class Channel::V2::SubscriptionsControllerTest < ActionController::TestCase
  include SubscriptionTestHelper
  include AccountTestHelper

  def setup
    super
    Account.any_instance.stubs(:account_additional_settings).returns(AccountAdditionalSettings.new(account_id: @account.id, email_cmds_delimeter: '@Simonsays', ticket_id_delimiter: '#', api_limit: 1000, additional_settings: {}))
    create_new_account('test1', 'test1@freshdesk.com')
    update_currency
    @account.subscription.update_attributes(agent_limit: 10) if @account.subscription.agent_limit.blank?
    Account.stubs(:current).returns(@account)
  end

  def teardown
    Account.unstub(:current)
    Account.any_instance.unstub(:account_additional_settings)
    @account.destroy
  end

  def wrap_cname(params)
    params
  end

  def build_params
    {
      "addons": {
        "add": [],
        "remove": []
      }
    }
  end

  def test_update_subscription_to_add_and_remove_addon
    set_jwt_auth_header('multiplexer')
    stub_chargebee_requests
    @account.launch :whatsapp_addon
    add_params = build_params
    add_params[:addons][:add] << { name: 'Native Whatsapp' }
    put :update, construct_params({ version: 'channel' }, add_params)
    updated_addon = @account.subscription.reload.addons.first
    assert_equal 'Native Whatsapp', updated_addon.name
    assert_response 200
    old_addon_count = @account.subscription.reload.addons.count
    remove_params = build_params
    remove_params[:addons][:remove] << { name: 'Native Whatsapp' }
    put :update, construct_params({ version: 'channel' }, remove_params)
    new_addons_count = @account.subscription.reload.addons.count
    assert_equal old_addon_count - 1, new_addons_count
    assert_response 200
  ensure
    @account.rollback :whatsapp_addon
    unstub_chargebee_requests
  end

  def test_update_subscription_when_existing_addon_added
    set_jwt_auth_header('multiplexer')
    stub_chargebee_requests
    @account.launch :whatsapp_addon
    add_params = build_params
    add_params[:addons][:add] << { name: 'Native Whatsapp' }
    put :update, construct_params({ version: 'channel' }, add_params)
    updated_addon = @account.subscription.reload.addons.first
    assert_equal 'Native Whatsapp', updated_addon.name
    assert_response 200
    put :update, construct_params({ version: 'channel' }, add_params)
    assert_response 400
    match_json([bad_request_error_pattern('addon', format(ErrorConstants::ERROR_MESSAGES[:duplicate_addon], addon: 'Native Whatsapp'))])
  ensure
    @account.rollback :whatsapp_addon
    unstub_chargebee_requests
  end

  def test_update_subscription_when_nonexisting_addon_removed
    set_jwt_auth_header('multiplexer')
    stub_chargebee_requests
    @account.launch :whatsapp_addon
    remove_params = build_params
    remove_params[:addons][:remove] << { name: 'Native Whatsapp' }
    put :update, construct_params({ version: 'channel' }, remove_params)
    assert_response 400
    match_json([bad_request_error_pattern('addon', format(ErrorConstants::ERROR_MESSAGES[:missing_addon], addon: 'Native Whatsapp'))])
  ensure
    @account.rollback :whatsapp_addon
    unstub_chargebee_requests
  end

  def test_update_subscription_when_invalid_addon_added
    set_jwt_auth_header('multiplexer')
    stub_chargebee_requests
    @account.launch :whatsapp_addon
    add_params = build_params
    add_params[:addons][:add] << { name: 'Dummy' }
    put :update, construct_params({ version: 'channel' }, add_params)
    assert_response 400
    match_json([bad_request_error_pattern('addon', format(ErrorConstants::ERROR_MESSAGES[:invalid_addon], addon: 'Dummy'))])
  ensure
    @account.rollback :whatsapp_addon
    unstub_chargebee_requests
  end

  def test_update_subscription_when_invalid_addon_for_plan_added
    set_jwt_auth_header('multiplexer')
    stub_chargebee_requests
    @account.launch :whatsapp_addon
    add_params = build_params
    add_params[:addons][:add] << { name: 'Chat' }
    put :update, construct_params({ version: 'channel' }, add_params)
    assert_response 400
    plan = @account.subscription.subscription_plan
    match_json([bad_request_error_pattern('addon', format(ErrorConstants::ERROR_MESSAGES[:addon_not_applicable], addon: 'Chat', plan: plan.name))])
  ensure
    @account.rollback :whatsapp_addon
    unstub_chargebee_requests
  end

  def stub_chargebee_requests
    @account.launch :downgrade_policy
    chargebee_update = ChargeBee::Result.new(stub_update_params(@account.id))
    ChargeBee::Subscription.stubs(:update).returns(chargebee_update)
    chargebee_estimate = ChargeBee::Result.new(stub_estimate_params)
    ChargeBee::Estimate.stubs(:update_subscription).returns(chargebee_estimate)
    chargebee_coupon = ChargeBee::Result.new(stub_chargebee_coupon)
    ChargeBee::Coupon.stubs(:retrieve).returns(chargebee_coupon)
    chargebee_plan = ChargeBee::Result.new(stub_chargebee_plan)
    ChargeBee::Plan.stubs(:retrieve).returns(chargebee_plan)
    ChargeBee::Subscription.stubs(:retrieve).returns(chargebee_update)
    @controller.stubs(:set_current_account).returns(@account)
    @controller.stubs(:request_host).returns('test1.freshpo.com')
    @account.subscription.state = 'active'
    @account.subscription.save!
    result = ChargeBee::Result.new(stub_update_params(@account.id))
    Billing::Subscription.any_instance.stubs(:retrieve_subscription).returns(result)
    Billing::Subscription.any_instance.stubs(:cancel_subscription).returns(true)
    Billing::Subscription.any_instance.stubs(:subscription_exists?).returns(true)
    Billing::Subscription.any_instance.stubs(:reactivate_subscription).returns(true)
    Billing::Subscription.any_instance.stubs(:coupon_applicable?).returns(true)
    ChargeBee::Subscription.stubs(:update).returns(result)
    Subscription.any_instance.stubs(:state).returns('free')
    Subscription.any_instance.stubs(:non_new_sprout?).returns(false)
  end

  def unstub_chargebee_requests
    @account.rollback :downgrade_policy
    ChargeBee::Subscription.unstub(:update)
    ChargeBee::Estimate.unstub(:update_subscription)
    ChargeBee::Subscription.unstub(:retrieve)
    ChargeBee::Plan.unstub(:retrieve)
    ChargeBee::Coupon.unstub(:retrieve)
    Subscription.any_instance.unstub(:active?)
    @controller.unstub(:set_current_account)
    @controller.unstub(:request_host)
    Billing::Subscription.any_instance.unstub(:retrieve_subscription)
    Billing::Subscription.any_instance.unstub(:cancel_subscription)
    Billing::Subscription.any_instance.unstub(:subscription_exists?)
    Billing::Subscription.any_instance.unstub(:reactivate_subscription)
    Billing::Subscription.any_instance.unstub(:coupon_applicable?)
    ChargeBee::Subscription.unstub(:update)
    Subscription.any_instance.unstub(:non_new_sprout?)
    Subscription.any_instance.unstub(:state)
  end
end
