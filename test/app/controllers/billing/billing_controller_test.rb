require_relative '../../../api/test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')
require Rails.root.join('test', 'models', 'helpers', 'subscription_test_helper.rb')

class Billing::BillingControllerTest < ActionController::TestCase
  include Billing::BillingHelper
  include AccountTestHelper
  include SubscriptionTestHelper
  include CoreUsersTestHelper

  def normal_event_content
    {
      customer: {
        id: @account.id,
        auto_collection: 'on'
      },
      subscription: {
        plan_id: Billing::Subscription.helpkit_plan.key(@account.plan_name.to_s).dup,
        plan_quantity: @account.subscription.agent_limit
      }
    }
  end

  def invoice_event_content
    {
      invoice: { customer_id: @account.id }
    }
  end

  def stub_subscription_settings(options = {})
    WebMock.allow_net_connect!
    Account.stubs(:current).returns(@account)
    update_params = stub_update_params(@account.id)
    update_params[:subscription].merge!(options[:addons]) if options[:addons]
    update_params[:subscription][:plan_id] = options[:plan_id] if options[:plan_id]
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
    WebMock.disable_net_connect!
  end

  def test_subscription_changed_event
    stub_subscription_settings
    user = add_new_user(@account)
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
    user = add_new_user(@account)
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

  def test_subscription_changed_event_with_subscribed_agent_count_less_than_agents
    stub_subscription_settings
    old_subscription = @account.subscription
    Subscription.any_instance.unstub(:update_attributes)
    Subscription.any_instance.unstub(:save)
    user = add_test_agent(@account)
    @account.launch(:downgrade_policy)
    post :trigger, event_type: 'subscription_changed', content: normal_event_content, format: 'json'
    assert_response 200
    assert_equal @account.reload.subscription.agent_limit, @account.full_time_support_agents.count
  ensure
    user.destroy
    @account.subscription.agent_limit = old_subscription.agent_limit
    @account.subscription.save
    unstub_subscription_settings
    @account.rollback(:downgrade_policy)
  end

  def test_subscription_changed_event_with_subscribed_agent_count_less_than_agents_and_without_sub_request
    stub_subscription_settings
    old_subscription = @account.subscription
    billing_data_subscription_plan = subscription_plan('forest_annual')
    Subscription.any_instance.unstub(:update_attributes)
    Subscription.any_instance.unstub(:save)
    user = add_test_agent(@account)
    @account.launch(:downgrade_policy)
    post :trigger, event_type: 'subscription_changed', content: normal_event_content, format: 'json'
    assert_response 200
    assert_equal @account.reload.subscription.agent_limit, @account.full_time_support_agents.count
    assert_equal @account.reload.subscription.subscription_plan, billing_data_subscription_plan
  ensure
    user.destroy
    @account.subscription.agent_limit = old_subscription.agent_limit
    @account.subscription.save
    unstub_subscription_settings
    @account.rollback(:downgrade_policy)
  end

  def test_subscription_changed_event_with_more_products_without_sub_request
    stub_subscription_settings
    old_subscription = @account.subscription
    current_plan_id = @account.subscription.subscription_plan_id
    Subscription.any_instance.unstub(:update_attributes)
    Subscription.any_instance.unstub(:save)
    @account.launch(:downgrade_policy)
    @account.add_feature(:unlimited_multi_product)
    6.times { @account.products.new(name: Faker::Lorem.characters(5)) }
    @account.save!
    SubscriptionPlan.any_instance.stubs(:unlimited_multi_product?).returns(false)
    SubscriptionPlan.any_instance.stubs(:multi_product?).returns(true)
    post :trigger, event_type: 'subscription_changed', content: normal_event_content, format: 'json'
    assert_response 200
    assert_equal @account.reload.subscription.subscription_plan_id, current_plan_id
  ensure
    unstub_subscription_settings
    SubscriptionPlan.any_instance.unstub(:unlimited_multi_product?)
    SubscriptionPlan.any_instance.unstub(:multi_product?)
    @account.rollback(:downgrade_policy)
  end

  def test_subscription_changed_event_with_more_products
    stub_subscription_settings
    old_subscription = @account.subscription
    current_plan_id = @account.subscription.subscription_plan_id
    Subscription.any_instance.unstub(:update_attributes)
    Subscription.any_instance.unstub(:save)
    @account.launch(:downgrade_policy)
    @account.add_feature(:unlimited_multi_product)
    6.times { @account.products.new(name: Faker::Lorem.characters(5)) }
    @account.save!
    SubscriptionPlan.any_instance.stubs(:unlimited_multi_product?).returns(false)
    SubscriptionPlan.any_instance.stubs(:multi_product?).returns(true)
    new_reminder = get_new_subscription_request(@account, @account.subscription.subscription_plan_id - 1, @account.subscription.renewal_period)
    post :trigger, event_type: 'subscription_changed', content: normal_event_content, format: 'json'
    assert_response 200
    assert_equal @account.reload.subscription.subscription_plan_id, current_plan_id
  ensure
    unstub_subscription_settings
    SubscriptionPlan.any_instance.unstub(:unlimited_multi_product?)
    SubscriptionPlan.any_instance.unstub(:multi_product?)
    @account.rollback(:downgrade_policy)
  end

  def setup_fsm_addon_with_field_agent_count(field_agent_count)
    subscription = @account.subscription
    fsm_addon = Subscription::Addon.find_by_name('Field Service Management')
    addon_mapping = subscription.subscription_addon_mappings.where(subscription_addon_id: fsm_addon.id)
    if addon_mapping.nil?
      addon_mapping = subscription.subscription_addon_mappings.new(subscription_addon_id: fsm_addon.id)
      addon_mapping.save!
    end
    if field_agent_count.nil?
      subscription.additional_info = subscription.additional_info.except(:field_agent_limit)
    else
      subscription.field_agent_limit=field_agent_count
    end
    subscription.save!
  end

  def test_subscription_changed_event_from_zero_to_ten_fsm_agents
    addon_params = { addons: [{ id: 'field_service_management', quantity: 10, object: 'addon' }] }
    stub_subscription_settings(addons: addon_params, plan_id: 'estate_jan_19_annual')
    setup_fsm_addon_with_field_agent_count(0)
    old_subscription = @account.subscription
    Rails.env.stubs(:test?).returns(false)
    Subscription.any_instance.unstub(:update_attributes)
    Subscription.any_instance.unstub(:save)
    ChargeBee::Subscription.any_instance.unstub(:plan_id)
    Billing::Subscription.any_instance.stubs(:calculate_update_subscription_estimate).raises(RuntimeError)
    post :trigger, event_type: 'subscription_changed', content: normal_event_content, format: 'json'
    assert_response 200
    assert_equal 10, @account.subscription.reload.field_agent_limit
  ensure
    @account.subscription.agent_limit = old_subscription.agent_limit
    @account.subscription.save
    Billing::Subscription.any_instance.unstub(:calculate_update_subscription_estimate)
    unstub_subscription_settings
  end

  def test_subscription_changed_event_from_nil_to_ten_fsm_agents
    addon_params = { addons: [{ id: 'field_service_management', quantity: 10, object: 'addon' }] }
    stub_subscription_settings(addons: addon_params, plan_id: 'estate_jan_19_annual')
    setup_fsm_addon_with_field_agent_count(nil)
    old_subscription = @account.subscription
    Rails.env.stubs(:test?).returns(false)
    Subscription.any_instance.unstub(:update_attributes)
    Subscription.any_instance.unstub(:save)
    ChargeBee::Subscription.any_instance.unstub(:plan_id)
    post :trigger, event_type: 'subscription_changed', content: normal_event_content, format: 'json'
    assert_response 200
    assert_equal 10, @account.subscription.reload.field_agent_limit
  ensure
    @account.subscription.agent_limit = old_subscription.agent_limit
    @account.subscription.save
    unstub_subscription_settings
  end

  def test_subscription_changed_event_from_two_to_ten_fsm_agents
    addon_params = { addons: [{ id: 'field_service_management', quantity: 10, object: 'addon' }] }
    stub_subscription_settings(addons: addon_params, plan_id: 'estate_jan_19_annual')
    setup_fsm_addon_with_field_agent_count(2)
    old_subscription = @account.subscription
    Rails.env.stubs(:test?).returns(false)
    Subscription.any_instance.unstub(:update_attributes)
    Subscription.any_instance.unstub(:save)
    ChargeBee::Subscription.any_instance.unstub(:plan_id)
    post :trigger, event_type: 'subscription_changed', content: normal_event_content, format: 'json'
    assert_response 200
    assert_equal 10, @account.subscription.reload.field_agent_limit
  ensure
    @account.subscription.agent_limit = old_subscription.agent_limit
    @account.subscription.save
    unstub_subscription_settings
  end

  def test_subscription_changed_event_with_marketplace_addon
    addon_params = { addons: [{ id: 'marketplaceapp_', quantity: 10, object: 'addon' }] }
    stub_subscription_settings(addons: addon_params, plan_id: 'estate_jan_19_annual')
    setup_fsm_addon_with_field_agent_count(2)
    old_subscription = @account.subscription
    Rails.env.stubs(:test?).returns(false)
    Subscription.any_instance.unstub(:update_attributes)
    Subscription.any_instance.unstub(:save)
    ChargeBee::Subscription.any_instance.unstub(:plan_id)
    Billing::Subscription.any_instance.stubs(:extension_details).raises(RuntimeError)
    post :trigger, event_type: 'subscription_changed', content: normal_event_content, format: 'json'
    assert_response 200
  ensure
    @account.subscription.agent_limit = old_subscription.agent_limit
    @account.subscription.save
    Billing::Subscription.any_instance.unstub(:extension_details)
    unstub_subscription_settings
  end

  def test_subscription_activated_event
    stub_subscription_settings
    ChatSetting.any_instance.stubs(:site_id).returns(1)
    ChargeBee::Subscription.any_instance.stubs(:status).returns('active')
    ChargeBee::Customer.any_instance.stubs(:card_status).returns('no_card')
    user = add_new_user(@account)
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
    @account = @account
    set_others_redis_key(card_expiry_key, 'test')
    user = add_new_user(@account)
    post :trigger, event_type: 'subscription_renewed', content: normal_event_content, format: 'json'
    assert_response 200
  ensure
    unstub_subscription_settings
    ChargeBee::Subscription.any_instance.unstub(:status)
    remove_others_redis_key(card_expiry_key)
  end

  def test_subscription_renewed_event_to_schedule
    stub_subscription_settings
    ChargeBee::Subscription.any_instance.stubs(:status).returns('active')
    user = add_new_user(@account)
    content = "{\"id\":\"ev_AzyyT8RpoY2XAyS9\",\"occurred_at\":1581076064,\"source\":\"scheduled_job\",\"object\":\"event\",\"api_version\":\"v1\",\"content\":{\"subscription\":{\"id\":\"1171555\",\"plan_id\":\"estate_omni_jan_19_monthly\",\"plan_quantity\":8,\"status\":\"active\",\"trial_start\":1565699778,\"trial_end\":1567853255,\"current_term_start\":1581076055,\"current_term_end\":1583581655,\"created_at\":1563205594,\"started_at\":1563205594,\"activated_at\":1567853255,\"has_scheduled_changes\":false,\"object\":\"subscription\",\"due_invoices_count\":1,\"due_since\":1581076055,\"total_dues\":68000},\"customer\":{\"id\":\"#{@account.id}\",\"first_name\":\"Youma\",\"last_name\":\"Fall\",\"email\":\"fall@paydunya.com\",\"company\":\"PayDunya\",\"auto_collection\":\"on\",\"allow_direct_debit\":false,\"created_at\":1563205594,\"taxability\":\"taxable\",\"object\":\"customer\",\"billing_address\":{\"first_name\":\"Youma\",\"last_name\":\"Dieng Fall\",\"line1\":\"Ouest foire Forum center\",\"city\":\"Dakar\",\"state\":\"Dakar\",\"country\":\"SN\",\"object\":\"billing_address\"},\"card_status\":\"valid\",\"payment_method\":{\"object\":\"payment_method\",\"type\":\"card\",\"reference_id\":\"cus_FlYZ27TcHO5R2T/pm_1FlYroFIIj5rWBMAXOD7A3jg\",\"gateway\":\"stripe\",\"status\":\"valid\"},\"account_credits\":0,\"refundable_credits\":0,\"excess_payments\":0,\"cf_account_domain\":\"paydunya.freshdesk.com\",\"meta_data\":{\"customer_key\":\"fdesk.1171555\"}},\"card\":{\"status\":\"valid\",\"reference_id\":\"cus_FlYZ27TcHO5R2T/pm_1FlYroFIIj5rWBMAXOD7A3jg\",\"gateway\":\"stripe\",\"first_name\":\"Youma\",\"last_name\":\"Dieng Fall\",\"iin\":\"******\",\"last4\":\"2339\",\"card_type\":\"visa\",\"expiry_month\":11,\"expiry_year\":2021,\"billing_addr1\":\"Ouest foire Forum center\",\"billing_city\":\"Dakar\",\"billing_state\":\"Dakar\",\"billing_country\":\"SN\",\"object\":\"card\",\"masked_number\":\"************2339\",\"customer_id\":\"1171555\"},\"invoice\":{\"id\":\"FD978228\",\"sub_total\":6887278,\"start_date\":1578397655,\"customer_id\":\"1171555\",\"subscription_id\":\"1171555\",\"recurring\":true,\"status\":\"payment_due\",\"price_type\":\"tax_exclusive\",\"end_date\":1581076055,\"amount\":68000,\"amount_paid\":0,\"amount_adjusted\":0,\"credits_applied\":0,\"amount_due\":68000,\"dunning_status\":\"in_progress\",\"next_retry\":1581248855,\"object\":\"invoice\",\"first_invoice\":false,\"currency_code\":\"[FILTERED]\",\"tax\":0,\"line_items\":[{\"date_from\":1581076055,\"entity_type\":\"plan\",\"type\":\"charge\",\"date_to\":1583581655,\"unit_amount\":8500,\"quantity\":8,\"amount\":68000,\"is_taxed\":false,\"tax\":0,\"object\":\"line_item\",\"description\":\"[FILTERED]\",\"entity_id\":\"estate_omni_jan_19_monthly\"}],\"linked_transactions\":[{\"txn_id\":\"txn_AzyyT8RpoY1HcyQN\",\"txn_type\":\"payment\",\"applied_amount\":68000,\"applied_at\":1581076064,\"txn_status\":\"failure\",\"txn_date\":1581076060,\"txn_amount\":68000}],\"linked_orders\":null,\"billing_address\":{\"first_name\":\"Youma\",\"last_name\":\"Dieng Fall\",\"company\":\"PayDunya\",\"line1\":\"Ouest foire Forum center\",\"city\":\"Dakar\",\"state\":\"Dakar\",\"country\":\"SN\",\"object\":\"billing_address\"},\"notes\":[{\"note\":\"\"}]}},\"event_type\":\"subscription_renewed\",\"webhook_status\":\"scheduled\",\"webhooks\":[{\"id\":\"wh_56\",\"webhook_status\":\"scheduled\",\"object\":\"webhook\"}],\"digest\":\"94224b4bec4ee74ceae02d9fb0a28bf4\",\"name_prefix\":\"fdadmin_\",\"path_prefix\":null,\"action\":\"trigger\",\"controller\":\"fdadmin/billing\"}"
    Billing::ChargebeeEventListener.expects(:perform_at).once
    post :trigger, event_type: 'subscription_renewed', content: JSON.parse(content)['content'], format: 'json'
    assert_response 200
  ensure
    unstub_subscription_settings
    ChargeBee::Subscription.any_instance.unstub(:status)
  end

  def test_subscription_cancelled_event
    stub_subscription_settings
    user = add_new_user(@account)
    Billing::BillingController.any_instance.stubs(:cancellation_requested?).returns(true)
    post :trigger, event_type: 'subscription_cancelled', content: normal_event_content, format: 'json'
    assert_response 200
  ensure
    Billing::BillingController.any_instance.unstub(:cancellation_requested?)
    unstub_subscription_settings
  end

  def test_account_cancellation_enqueued_after_subscription_cancelled
    stub_subscription_settings
    user = add_new_user(@account)
    post :trigger, event_type: 'subscription_cancelled', content: normal_event_content, format: 'json'
    assert_equal 1, ::Scheduler::PostMessage.jobs.size
  ensure
    unstub_subscription_settings
  end

  def test_subscription_reactivated_event
    stub_subscription_settings
    user = add_new_user(@account)
    post :trigger, event_type: 'subscription_reactivated', content: normal_event_content, format: 'json'
    assert_response 200
  ensure
    unstub_subscription_settings
  end

  def test_subscription_reactivated_event_with_pending_cancellation_request
    stub_subscription_settings
    user = add_new_user(@account)
    @account.launch(:downgrade_policy)
    set_others_redis_key(@account.account_cancellation_request_time_key, (Time.now.to_f * 1000).to_i, nil)
    post :trigger, event_type: 'subscription_reactivated', content: normal_event_content, format: 'json'
    assert_response 200
    refute @account.account_cancellation_requested_time
  ensure
    unstub_subscription_settings
    @account.rollback(:downgrade_policy)
  end

  def test_subscription_scheduled_cancellation_removed_event
    stub_subscription_settings
    user = add_new_user(@account)
    post :trigger, event_type: 'subscription_scheduled_cancellation_removed', content: normal_event_content, format: 'json'
    assert_response 200
  ensure
    unstub_subscription_settings
  end

  def test_card_added_event
    stub_subscription_settings
    user = add_new_user(@account)
    content = normal_event_content
    content[:customer][:card_status] = 'valid'
    post :trigger, event_type: 'card_added', content: content, format: 'json'
    assert_response 200
  ensure
    unstub_subscription_settings
  end

  def test_card_deleted_event
    stub_subscription_settings
    user = add_new_user(@account)
    post :trigger, event_type: 'card_deleted', content: normal_event_content, format: 'json'
    assert_response 200
  ensure
    unstub_subscription_settings
  end

  def test_card_deleted_event_should_not_delete_card_if_subscription_has_card
    stub_subscription_settings
    user = add_new_user(@account)
    subscription = @account.subscription
    card_number = subscription.card_number
    subscription.card_number = '************4242'
    subscription.save
    post :trigger, event_type: 'card_deleted', content: normal_event_content, format: 'json'
    assert_response 200
    assert_equal @account.subscription.card_number, '************4242'
  ensure
    subscription.card_number = card_number
    subscription.save
    unstub_subscription_settings
  end

  def test_card_expiring_event
    stub_subscription_settings
    user = add_new_user(@account)
    post :trigger, event_type: 'card_expiring', content: normal_event_content, format: 'json'
    assert_response 200
  ensure
    unstub_subscription_settings
  end

  def test_customer_changed_event
    stub_subscription_settings
    user = add_new_user(@account)
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
    user = add_new_user(@account)
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
    user = add_new_user(@account)
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
