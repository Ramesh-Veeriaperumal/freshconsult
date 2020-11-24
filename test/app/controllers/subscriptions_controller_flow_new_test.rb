# frozen_string_literal:true

require_relative '../../api/api_test_helper'
require Rails.root.join('test', 'models', 'helpers', 'subscription_test_helper.rb')

class SubscriptionControllerFlowTest < ActionDispatch::IntegrationTest
  include UsersHelper
  include SubscriptionTestHelper

  def setup
    super
    @agent_limit = @account.subscription.agent_limit
    @subscription_state = @account.subscription.state
    @account.subscription.agent_limit = 10
    @account.subscription.state = 'active'
    @account.subscription.save!
    stub_chargebee_common_requests(@account.id)
  end

  def teardown
    @account.make_current
    @account.subscription.agent_limit = @agent_limit
    @account.subscription.state = @subscription_state
    @account.subscription.save!
    unstub_chargebee_common_requests
    super
  end

  # billing action related tests
  def test_subscription_billing_choose_plan
    # When the agent limit of the current subscription is nil, validate_subscription redirects with a flash
    agent = add_test_agent(@account)
    billing_params = { charge_now: false }
    SubscriptionsController.any_instance.stubs(:load_coupon).returns(nil)
    set_request_auth_headers(agent)
    @account.subscription.agent_limit = nil
    @account.subscription.save!
    post '/subscription/billing', billing_params
    assert_equal I18n.t('subscription.error.choose_plan'), flash[:notice]
    assert_redirected_to subscription_url
    assert_response 302
  ensure
    SubscriptionsController.any_instance.unstub(:load_coupon)
  end

  def test_subscription_billing_with_validation_error
    # Updating billing info when verify multiple products check fails (account has more no. of products than allowed limit)
    agent = add_test_agent(@account)
    billing_params = { charge_now: false }
    Subscription.any_instance.stubs(:chk_multi_product).returns(true)
    set_request_auth_headers(agent)
    post '/subscription/billing', billing_params
    assert_equal true, flash[:notice].present?
    assert_redirected_to subscription_url
    assert_response 302
  ensure
    Subscription.any_instance.unstub(:chk_multi_product)
  end

  def test_subscription_billing_error_in_adding_card
    # When chargebee throws while adding card to billing
    agent = add_test_agent(@account)
    billing_params = { charge_now: false }
    SubscriptionsController.any_instance.stubs(:load_coupon).returns(nil)
    ChargeBee::Subscription.stubs(:retrieve).raises(ChargeBee::InvalidRequestError.new('dummy error', dummy_error_hash))
    set_request_auth_headers(agent)
    post '/subscription/billing', billing_params
    assert_equal dummy_error_hash[:error_msg], flash[:notice]
    assert_redirected_to '/subscription/billing'
    assert_response 302
  ensure
    SubscriptionsController.any_instance.unstub(:load_coupon)
  end

  def test_subscription_billing_error_in_updating_plan
    # When chargebee throws while updating the plan after adding card
    agent = add_test_agent(@account)
    billing_params = { charge_now: false }
    stub_estimate_create_subscription
    ChargeBee::Subscription.stubs(:update).raises(ChargeBee::InvalidRequestError.new('dummy error', dummy_error_hash))
    set_request_auth_headers(agent)
    post '/subscription/billing', billing_params
    assert_equal dummy_error_hash[:error_msg], flash[:notice]
    assert_redirected_to subscription_url
    assert_response 302
  ensure
    unstub_estimate_create_subscription
  end

  def test_subscription_billing_without_payment
    # When account's billing info is updated and not charged
    agent = add_test_agent(@account)
    billing_params = { charge_now: false }
    stub_estimate_create_subscription
    set_request_auth_headers(agent)
    post '/subscription/billing', billing_params
    assert_equal I18n.t('billing_info_update'), flash[:notice]
    assert_response 302
  ensure
    unstub_estimate_create_subscription
  end

  def test_subscription_billing_without_payment_xhr_request
    # When account's billing info is updated and not charged (xhr)
    agent = add_test_agent(@account)
    billing_params = { charge_now: false }
    stub_estimate_create_subscription
    set_request_auth_headers(agent)
    xhr :post, '/subscription/billing', billing_params
    assert_equal I18n.t('billing_info_update'), flash[:notice]
    assert_response 200
  ensure
    unstub_estimate_create_subscription
  end

  def test_post_subscription_billing_after_payment
    # When account billing info is updated and is charged
    agent = add_test_agent(@account)
    billing_params = { charge_now: true }
    stub_estimate_create_subscription
    set_request_auth_headers(agent)
    post '/subscription/billing', billing_params
    assert_equal I18n.t('card_process'), flash[:notice]
    assert_response 302
  ensure
    unstub_estimate_create_subscription
  end

  def test_post_subscription_billing_after_payment_with_downgrade_policy
    # Account billing info is updated and is charged when dp feature is enabled
    @account.launch(:downgrade_policy)
    agent = add_test_agent(@account)
    billing_params = { charge_now: true }
    stub_estimate_create_subscription
    set_request_auth_headers(agent)
    post '/subscription/billing', billing_params
    assert_equal I18n.t('card_process'), flash[:notice]
    assert_response 302
  ensure
    unstub_estimate_create_subscription
  end

  def test_get_subscription_billing
    # get request for billing , updates the payment method in chargebee.
    agent = add_test_agent(@account)
    billing_params = { charge_now: true }
    stub_estimate_create_subscription
    stub_chargebee_update_payment
    set_request_auth_headers(agent)
    get '/subscription/billing'
    assert_response 200
  ensure
    unstub_estimate_create_subscription
    unstub_chargebee_update_payment
  end

  def test_subscription_billing_exceed_card_update_limit
    agent = add_test_agent(@account)
    billing_params = { charge_now: false }
    stub_estimate_create_subscription
    set_request_auth_headers(agent)
    # number of updates to card info is limited to 5/per hour
    6.times { post '/subscription/billing', billing_params }
    assert_equal I18n.t('subscription.error.card_update_limit_exceeded'), flash[:notice]
    assert_response 302
  ensure
    unstub_estimate_create_subscription
  end

  # calculate_amount action related tests
  def test_post_calculate_amount
    agent = add_test_agent(@account)
    stub_chargebee_addon
    stub_estimate_create_subscription
    params = { billing_cycle: SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:annual], agent_limit: 25, addons: { freddy_self_service: { enabled: false }, freddy_ultimate: { enabled: false }, freddy_session_packs: { enabled: false } }, plan_id: @account.subscription.subscription_plan.id, currency: 'USD', request_change: true }
    set_request_auth_headers(agent)
    post '/subscription/calculate_amount', params
    assert_response 200
  ensure
    unstub_chargebee_addon
    unstub_estimate_create_subscription
  end

  # calculate_plam_amount action related tests
  def test_post_calculate_plan_amount
    agent = add_test_agent(@account)
    stub_chargebee_addon
    params = { currency: 'AUD' }
    set_request_auth_headers(agent)
    post '/subscription/calculate_plan_amount', params
    assert_response 200
  ensure
    unstub_chargebee_addon
  end

  # plan action related_tests
  def test_post_plan
    # card needed while changing plan
    agent = add_test_agent(@account)
    set_request_auth_headers(agent)
    post '/subscription/plan', plan_params_hash
    assert_response 302
  end

  def test_post_plan_for_dp_enabled_account
    # Redirected to subscription url when failed to update subscription as dp is enabled.
    @account.launch(:downgrade_policy)
    agent = add_test_agent(@account)
    stub_chargebee_addon
    params = { agent_limit: 5 }
    set_request_auth_headers(agent)
    post '/subscription/plan', params.merge!(plan_params_hash.except(:agent_limit))
    assert_redirected_to subscription_url
    assert_response 302
  ensure
    unstub_chargebee_addon
  end

  def test_post_plan_for_omni_bundle_enabled_account
    # When an omni bundle account.
    @account.rollback(:downgrade_policy)
    Account.any_instance.stubs(:omni_bundle_account?).returns(true)
    agent = add_test_agent(@account)
    stub_chargebee_addon
    params = { agent_limit: 5 }
    set_request_auth_headers(agent)
    SubscriptionsController.any_instance.expects(:construct_payload_for_ui_update).once
    post '/subscription/plan', params.merge!(plan_params_hash.except(:agent_limit))
    assert_response 302
  ensure
    Account.any_instance.unstub(:omni_bundle_account?)
    unstub_chargebee_addon
  end

  def test_post_plan_for_dp_enabled_account_raises_error
    # Redirected to subscription url when failed to update subscription due to chargebee error.
    @account.launch(:downgrade_policy)
    agent = add_test_agent(@account)
    stub_chargebee_addon
    params = { agent_limit: 5 }
    set_request_auth_headers(agent)
    ChargeBee::Subscription.stubs(:update).raises(ChargeBee::InvalidRequestError.new('dummy error', dummy_error_hash))
    post '/subscription/plan', params.merge!(plan_params_hash.except(:agent_limit))
    assert_redirected_to subscription_url
    assert_equal dummy_error_hash[:error_msg], flash[:notice]
    assert_response 302
  ensure
    unstub_chargebee_addon
  end

  def test_post_plan_for_active_acc_with_card_number
    # card not needed when changing plan, renders :show
    agent = add_test_agent(@account)
    @account.subscription.state = 'active'
    @account.subscription.card_number = '************1111'
    @account.subscription.save!
    set_request_auth_headers(agent)
    post '/subscription/plan', plan_params_hash.except(:plan_switch)
    assert_equal I18n.t('plan_info_update'), flash[:notice]
    assert_response 302
  end

  def test_post_plan_for_acc_in_active_trial_plan_with_plan_switch
    # Changing plan when current account is in active trial
    agent = add_test_agent(@account)
    Account.any_instance.stubs(:active_trial).returns(TrialSubscription.new)
    @account.subscription.state = 'trial'
    @account.subscription.save!
    set_request_auth_headers(agent)
    post '/subscription/plan', plan_params_hash
    assert_equal I18n.t('plan_info_update'), flash[:notice]
    assert_response 302
  ensure
    Account.any_instance.unstub(:active_trial)
  end

  def test_post_plan_for_xhr_request
    # Changing plan - xhr - renders calculate amount partial
    agent = add_test_agent(@account)
    @account.subscription.state = 'trial'
    @account.subscription.save!
    stub_estimate_create_subscription
    stub_chargebee_addon
    set_request_auth_headers(agent)
    xhr :post, '/subscription/plan', plan_params_hash
    assert_template('calculate_amount')
    assert_response 200
  ensure
    unstub_chargebee_addon
    unstub_estimate_create_subscription
  end

  def test_post_plan_not_having_valid_currency
    # Sending invalid currency type in params while changing plan
    agent = add_test_agent(@account)
    params = { currency: 'invalid_currency' }
    set_request_auth_headers(agent)
    post '/subscription/plan', params.merge!(plan_params_hash.except(:currency))
    assert_equal I18n.t('subscription.error.invalid_currency'), flash[:error]
    assert_response 302
  end

  def test_post_plan_with_switch_currency
    # switch currency and clone subscription in new site by creating new as old subscription does not exist
    agent = add_test_agent(@account)
    @account.subscription.currency = Subscription::Currency.find_by_name('USD')
    @account.subscription.state = 'trial'
    @account.subscription.save!
    stub_chargebee_cancel_subscription(@account.id)
    stub_chargebee_create_subscription(@account.id)
    stub_chargebee_update_customer
    Billing::Subscription.any_instance.stubs(:subscription_exists?).returns(false)
    set_request_auth_headers(agent)
    params = { currency: 'AUD' }
    post '/subscription/plan', params.merge!(plan_params_hash.except(:currency))
    @account.reload
    assert_equal I18n.t('plan_info_update'), flash[:notice]
    assert_equal params[:currency], @account.subscription.currency.name
    assert_response 302
  ensure
    Billing::Subscription.any_instance.unstub(:subscription_exists?)
    unstub_chargebee_cancel_subscription
    unstub_chargebee_create_subscription
    unstub_chargebee_update_customer
  end

  def test_post_plan_for_sprout
    # When changing plan to free and there is error while updating chargebee (activate_subscription is false)
    agent = add_test_agent(@account)
    plan_ids = SubscriptionPlan.current.map(&:id)
    sprout_plan_id = SubscriptionPlan.current.where(id: plan_ids).map { |x| x.id if x.amount == 0.0 }.compact.first
    @account.rollback(:downgrade_policy)
    params_hash = { currency: 'USD', plan_id: sprout_plan_id, billing_cycle: SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:annual], agent_limit: '' }
    post '/subscription/plan', params_hash
    @account.make_current
    set_request_auth_headers(agent)
    SubscriptionsController.any_instance.stubs(:activate_subscription).returns(false)
    post '/subscription/plan', plan_params_hash.except(:plan_id)
    assert_equal I18n.t('error_in_plan'), flash[:notice]
    assert_response 302
  ensure
    SubscriptionsController.any_instance.unstub(:activate_subscription)
  end

  private

    def plan_params_hash
      {
        billing_cycle: SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:annual],
        agent_limit: '',
        currency: 'USD',
        plan_id: @account.subscription.subscription_plan.omni_plan_variant.id.to_s,
        addons:
          {
            field_service_management:
              {
                enabled: false,
                value: 0
              }
          },
        plan_switch: 1
      }
    end

    def dummy_error_hash
      { message: 'dummy message', api_error_code: 'dummy error code', error_msg: 'dummy error msg' }
    end

    def old_ui?
      true
    end
end
