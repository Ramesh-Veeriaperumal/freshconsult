require_relative '../../../api/test_helper'

class Billing::BillingControllerTest < ActionController::TestCase
  include Billing::BillingHelper
  def current_account
    Account.first.make_current
  end

  def normal_event_content
    {
      customer: {
        id: current_account.id,
        auto_collection: 'on'
      }
    }
  end

  def invoice_event_content
    {
      invoice: { customer_id: current_account.id }
    }
  end

  def stub_subscription_settings
    WebMock.allow_net_connect!
    Digest::MD5.stubs(:hexdigest).returns('5c8231431eca2c61377371de706a52cc')
    @controller.request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials('freshdesk', 'freshdesk')
    ChargeBee::Subscription.any_instance.stubs(:plan_id).returns('forest_annual')
    Subscription.any_instance.stubs(:update_attributes).returns(true)
    Subscription.any_instance.stubs(:save).returns(true)
    AccountAdditionalSettings.any_instance.stubs(:set_payment_preference).returns(true)
    Subscription::UpdatePartnersSubscription.stubs(:perform_async).returns(true)
  end

  def unstub_subscription_settings
    Digest::MD5.unstub(:hexdigest)
    ChargeBee::Subscription.any_instance.unstub(:plan_id)
    Subscription.any_instance.unstub(:update_attributes)
    Subscription.any_instance.unstub(:save)
    AccountAdditionalSettings.any_instance.unstub(:set_payment_preference)
    Subscription::UpdatePartnersSubscription.unstub(:perform_async)
    WebMock.disable_net_connect!
  end

  def test_subscription_changed_event
    stub_subscription_settings
    user = add_new_user(current_account)
    ChargeBee::Subscription.any_instance.stubs(:addons).returns([Subscription::Addon.new])
    Subscription::Addon.stubs(:fetch_addon).returns(Subscription::Addon.new)
    ChargeBee::Customer.any_instance.stubs(:auto_collection).returns('off')
    ChargeBee::Subscription.any_instance.stubs(:status).returns('active')
    post :trigger, event_type: 'subscription_changed', content: normal_event_content, format: 'xml'
  ensure
    unstub_subscription_settings
    ChargeBee::Subscription.any_instance.unstub(:addons)
    Subscription::Addon.unstub(:fetch_addon)
    ChargeBee::Customer.any_instance.unstub(:auto_collection)
    ChargeBee::Subscription.any_instance.unstub(:status)
  end

  def test_subscription_changed_event_with_new_plan
    stub_subscription_settings
    user = add_new_user(current_account)
    Subscription.any_instance.stubs(:addons).returns([Subscription::Addon.new])
    Subscription::Addon.stubs(:fetch_addon).returns(Subscription::Addon.new)
    ChargeBee::Subscription.any_instance.stubs(:status).returns('in_trial')
    @controller.stubs(:plan_changed?).returns(true)
    @controller.stubs(:addons_changed?).returns(true)
    @controller.stubs(:omni_plan_change?).returns(true)
    @controller.stubs(:omni_channel_ticket_params).returns({})
    Account.any_instance.stubs(:active_trial).returns(TrialSubscription.new)
    TrialSubscription.any_instance.stubs(:update_result!).returns(true)
    ProductFeedbackWorker.stubs(:perform_async).returns(true)
    post :trigger, event_type: 'subscription_changed', content: normal_event_content, format: 'xml'
    assert_response 200
  ensure
    unstub_subscription_settings
    Subscription.any_instance.unstub(:addons)
    Subscription::Addon.unstub(:fetch_addon)
    @controller.unstub(:plan_changed?)
    @controller.unstub(:addons_changed?)
    @controller.unstub(:omni_plan_change?)
    @controller.unstub(:omni_channel_ticket_params)
    Account.any_instance.unstub(:active_trial)
    TrialSubscription.any_instance.unstub(:update_result!)
    ProductFeedbackWorker.unstub(:perform_async)
    ChargeBee::Subscription.any_instance.unstub(:status)
  end

  def test_subscription_activated_event
    stub_subscription_settings
    ChatSetting.any_instance.stubs(:site_id).returns(1)
    ChargeBee::Subscription.any_instance.stubs(:status).returns('active')
    ChargeBee::Customer.any_instance.stubs(:card_status).returns('no_card')
    user = add_new_user(current_account)
    post :trigger, event_type: 'subscription_activated', content: normal_event_content, format: 'json'
  ensure
    unstub_subscription_settings
    ChatSetting.any_instance.unstub(:site_id)
    ChargeBee::Subscription.any_instance.unstub(:status)
    ChargeBee::Customer.any_instance.unstub(:card_status)
  end

  def test_subscription_renewed_event
    stub_subscription_settings
    ChargeBee::Subscription.any_instance.stubs(:status).returns('active')
    @account = current_account
    set_others_redis_key(card_expiry_key, 'test')
    user = add_new_user(current_account)
    post :trigger, event_type: 'subscription_renewed', content: normal_event_content, format: 'json'
    assert_response 200
  ensure
    unstub_subscription_settings
    ChargeBee::Subscription.any_instance.unstub(:status)
    remove_others_redis_key(card_expiry_key)
  end

  def test_subscription_cancelled_event
    stub_subscription_settings
    user = add_new_user(current_account)
    post :trigger, event_type: 'subscription_cancelled', content: normal_event_content, format: 'json'
    assert_response 200
  ensure
    unstub_subscription_settings
  end

  def test_subscription_reactivated_event
    stub_subscription_settings
    user = add_new_user(current_account)
    post :trigger, event_type: 'subscription_reactivated', content: normal_event_content, format: 'json'
    assert_response 200
  ensure
    unstub_subscription_settings
  end

  def test_subscription_reactivated_event_with_pending_cancellation_request
    stub_subscription_settings
    user = add_new_user(current_account)
    current_account.launch(:downgrade_policy)
    set_others_redis_key(current_account.account_cancellation_request_time_key, (Time.now.to_f * 1000).to_i, nil)
    post :trigger, event_type: 'subscription_reactivated', content: normal_event_content, format: 'json'
    assert_response 200
    refute current_account.account_cancellation_requested_time
  ensure
    unstub_subscription_settings
    current_account.rollback(:downgrade_policy)
  end

  def test_subscription_scheduled_cancellation_removed_event
    stub_subscription_settings
    user = add_new_user(current_account)
    post :trigger, event_type: 'subscription_scheduled_cancellation_removed', content: normal_event_content, format: 'json'
    assert_response 200
  ensure
    unstub_subscription_settings
  end

  def test_card_added_event
    stub_subscription_settings
    user = add_new_user(current_account)
    content = normal_event_content
    content[:customer][:card_status] = 'valid'
    post :trigger, event_type: 'card_added', content: content, format: 'json'
    assert_response 200
  ensure
    unstub_subscription_settings
  end

  def test_card_deleted_event
    stub_subscription_settings
    user = add_new_user(current_account)
    post :trigger, event_type: 'card_deleted', content: normal_event_content, format: 'json'
    assert_response 200
  ensure
    unstub_subscription_settings
  end

  def test_card_expiring_event
    stub_subscription_settings
    user = add_new_user(current_account)
    post :trigger, event_type: 'card_expiring', content: normal_event_content, format: 'json'
    assert_response 200
  ensure
    unstub_subscription_settings
  end

  def test_customer_changed_event
    stub_subscription_settings
    user = add_new_user(current_account)
    content = normal_event_content
    content[:customer][:auto_collection] = 'off'
    post :trigger, event_type: 'customer_changed', content: content, format: 'json'
    assert_response 200
  ensure
    unstub_subscription_settings
  end

  def test_payment_succeeded_event
    stub_subscription_settings
    Billing::WebhookParser.any_instance.stubs(:invoice_hash).returns(chargebee_invoice_id: 1)
    user = add_new_user(current_account)
    content = normal_event_content
    content[:transaction] = {
      amount: 2000
    }
    content[:invoice] = {
      id: 1,
      status: 'paid',
      line_items: [{ description: Faker::Lorem.word }]
    }
    post :trigger, event_type: 'payment_succeeded', content: content, source: 'api', format: 'json'
    assert_response 200
  ensure
    unstub_subscription_settings
    Billing::WebhookParser.any_instance.unstub(:invoice_hash)
  end

  def test_payment_refunded_event
    stub_subscription_settings
    Billing::WebhookParser.any_instance.stubs(:invoice_hash).returns(chargebee_invoice_id: 1)
    user = add_new_user(current_account)
    content = normal_event_content
    content[:transaction] = {
      amount: 2000
    }
    post :trigger, event_type: 'payment_refunded', content: content, format: 'json'
    assert_response 200
  ensure
    unstub_subscription_settings
    Billing::WebhookParser.any_instance.unstub(:invoice_hash)
  end

  def test_triggering_invalid_event_with_json_response
    stub_subscription_settings
    post :trigger, event_type: 'payment_done', content: normal_event_content, format: 'json'
    assert_response 200
  ensure
    unstub_subscription_settings
  end

  def test_triggering_invalid_event_with_xml_response
    stub_subscription_settings
    post :trigger, event_type: 'payment_done', content: normal_event_content, format: 'xml'
    assert_response 200
  ensure
    unstub_subscription_settings
  end

  def test_triggerring_events_with_invalid_account_id_with_json_response
    stub_subscription_settings
    Account.stubs(:find_by_id).returns(nil)
    post :trigger, event_type: 'payment_refunded', content: normal_event_content, format: 'json'
    assert_response 404
  ensure
    unstub_subscription_settings
    Account.unstub(:find_by_id)
  end

  def test_subscription_cancelled_event_with_invalid_account_id_and_xml_response
    stub_subscription_settings
    Account.stubs(:find_by_id).returns(nil)
    post :trigger, event_type: 'subscription_cancelled', content: normal_event_content, format: 'xml'
    assert_response 200
  ensure
    unstub_subscription_settings
    Account.unstub(:find_by_id)
  end

  def test_subscription_cancelled_event_with_invalid_account_id_and_json_response
    stub_subscription_settings
    Account.stubs(:find_by_id).returns(nil)
    post :trigger, event_type: 'subscription_cancelled', content: normal_event_content, format: 'json'
    assert_response 200
  ensure
    unstub_subscription_settings
    Account.unstub(:find_by_id)
  end

  def test_triggerring_event_without_authorization_header
    post :trigger, content: normal_event_content, format: 'xml'
    assert_response 401
  end

  def test_triggerring_event_with_invalid_pod_set
    stub_subscription_settings
    ShardMapping.any_instance.stubs(:pod_info).returns('useast')
    ActionController::TestRequest.any_instance.stubs(:request_uri).returns('/helpdesk')
    post :trigger, event_type: 'card_expiring', content: normal_event_content, format: 'json'
    assert_response 302
  ensure
    unstub_subscription_settings
    ShardMapping.any_instance.unstub(:pod_info)
    ActionController::TestRequest.any_instance.unstub(:request_uri)
  end
end
