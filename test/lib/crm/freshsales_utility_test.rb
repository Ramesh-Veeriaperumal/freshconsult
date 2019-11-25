require_relative '../test_helper'
require Rails.root.join('spec', 'support', 'account_helper.rb')

class FreshsalesUtilityTest < ActionView::TestCase
  include AccountHelper

  def setup
    super
    before_all
  end

  @@before_all_run = false

  def before_all
    return if @@before_all_run
    create_test_account
    @cmrr = @account.subscription.cmrr
    @subscription = @account.subscription
    @account.conversion_metric = ConversionMetric.new(account_id: @account.id)
    @account.conversion_metric.save!
    Account.stubs(:first).returns(Account.current)
    @@before_all_run = true
  end

  def teardown
    super
  end

  def test_lead_and_campaign_info
    CRM::FreshsalesUtility.any_instance.stubs(:get_entity_id).returns(1)
    options = { rest_url: '/settings/leads/fields', method: 'get' }
    CRM::FreshsalesUtility.any_instance.stubs(:request_freshsales).with(options).returns([200, { fields: [{ name: 'lead_source_id', choices: [{ id: 1, value: 'Inbound' }, { id: 2, value: 'Text in FS' }] }, { name: 'campaign_id', choices: [{ id: 2, value: 'Trial Signup' }] }] }])
    @fresh_sales_utility = CRM::FreshsalesUtility.new(cmrr: @account.subscription.cmrr, account: @account, subscription: @account.subscription)
    ConversionMetric.any_instance.stubs(:lead_source_choice).returns(nil)
    response = @fresh_sales_utility.send(:get_lead_source_and_campaign_id)
    assert_equal response[:lead_source_id], 1

    ConversionMetric.any_instance.stubs(:lead_source_choice).returns('Text in FS')
    response = @fresh_sales_utility.send(:get_lead_source_and_campaign_id)
    assert_equal response[:lead_source_id], 2

    ConversionMetric.any_instance.stubs(:lead_source_choice).returns('Text not in FS')
    response = @fresh_sales_utility.send(:get_lead_source_and_campaign_id)
    assert_equal response[:lead_source_id], 1
  ensure
    CRM::FreshsalesUtility.any_instance.unstub(:request_freshsales)
    CRM::FreshsalesUtility.any_instance.unstub(:get_entity_id)
    ConversionMetric.any_instance.unstub(:lead_source_choice)
  end

  def test_get_signup_data
    CRM::FreshsalesUtility.any_instance.stubs(:get_lead_source_and_campaign_id).returns(lead_source_id: 1, campaign_id: 2)
    HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(custom_field: { cf_is_farming_account: true }, text: { :lead => { id: 1 }, 'deal_products' => [Account.current], :fields => [Helpdesk::TicketField.new(name: 'lead_source_id'), Helpdesk::TicketField.new(name: 'campaign_id')] }.to_json, status: 200)
    CRM::FreshsalesUtility.any_instance.stubs(:search_accounts_by_email_domain).returns([{ custom_field: { cf_is_farming_account: true }, owner_id: 1 }])
    resp = CRM::FreshsalesUtility.new(cmrr: @account.subscription.cmrr, account: @account, subscription: @account.subscription).push_signup_data(fs_cookie: 1)
    assert_equal resp[1][:lead].to_json, { id: 1 }.to_json

    CRM::FreshsalesUtility.any_instance.stubs(:search_accounts_by_email_domain).returns([{ custom_field: { cf_is_farming_account: false }, owner_id: 1 }])
    CRM::FreshsalesUtility.any_instance.stubs(:request_freshsales).returns([200, { :lead => { id: 1 }, 1 => { contacts: [{ owner_id: '1', updated_at: Date.current.to_s }], leads: [{ updated_at: 1 }] } }])
    CRM::FreshsalesUtility.any_instance.stubs(:get_entity_id).returns(1)
    resp = CRM::FreshsalesUtility.new(cmrr: @account.subscription.cmrr, account: @account, subscription: @account.subscription).push_signup_data(fs_cookie: 1)
    assert_equal resp[1][1].to_json, { contacts: [{ owner_id: '1', updated_at: Date.current.to_s }], leads: [{ updated_at: 1 }] }.to_json

    CRM::FreshsalesUtility.any_instance.stubs(:request_freshsales).returns([200, { :lead => { id: 1, lead_stages: {} }, 1 => { contacts: [], leads: [{ updated_at: 1 }] } }])
    resp = CRM::FreshsalesUtility.new(cmrr: @account.subscription.cmrr, account: @account, subscription: @account.subscription).push_signup_data(fs_cookie: 1)
    assert_equal resp[1][:lead].to_json, { id: 1, lead_stages: {} }.to_json

    CRM::FreshsalesUtility.any_instance.stubs(:request_freshsales).returns([200, { :lead => {}, 1 => { sales_accounts: [owner_id: '1', updated_at: Date.current.to_s], contacts: [], leads: [] } }])
    resp = CRM::FreshsalesUtility.new(cmrr: @account.subscription.cmrr, account: @account, subscription: @account.subscription).push_signup_data(fs_cookie: 1)
    assert_equal resp[1][1].to_json, { sales_accounts: [{ owner_id: '1', updated_at: Date.current.to_s }], contacts: [], leads: [] }.to_json
  ensure
    CRM::FreshsalesUtility.any_instance.unstub(:request_freshsales)
    CRM::FreshsalesUtility.any_instance.unstub(:get_entity_id)
    CRM::FreshsalesUtility.any_instance.unstub(:get_lead_source_and_campaign_id)
    CRM::FreshsalesUtility.any_instance.unstub(:search_accounts_by_email_domain)
    HttpRequestProxy.any_instance.unstub(:fetch_using_req_params)
  end

  def test_update_admin_info
    CRM::FreshsalesUtility.any_instance.stubs(:search).returns(deals: [{ deal_product_id: '1' }], contacts: [{ email: 'sample@freshdesk.com' }])
    CRM::FreshsalesUtility.any_instance.stubs(:get_entity_id).returns('1')
    CRM::FreshsalesUtility.new(cmrr: @account.subscription.cmrr, account: @account, subscription: @account.subscription).update_admin_info
    assert_equal response.status, 200

    CRM::FreshsalesUtility.any_instance.stubs(:search).returns(deals: [{ deal_product_id: '1', sales_account_id: '1' }], contacts: [], sales_accounts: [{ id: '1' }])
    CRM::FreshsalesUtility.new(cmrr: @account.subscription.cmrr, account: @account, subscription: @account.subscription).update_admin_info
    assert_equal response.status, 200

    CRM::FreshsalesUtility.any_instance.stubs(:search).returns(deals: [], contacts: [], sales_accounts: [{ id: '1' }])
    CRM::FreshsalesUtility.any_instance.stubs(:search_leads_by_account_and_product).returns(leads: [{ email: 'sample@freshdesk.com', updated_at: Date.current.to_s }])
    CRM::FreshsalesUtility.new(cmrr: @account.subscription.cmrr, account: @account, subscription: @account.subscription).update_admin_info
    assert_equal response.status, 200
  ensure
    CRM::FreshsalesUtility.any_instance.unstub(:search)
    CRM::FreshsalesUtility.any_instance.unstub(:get_entity_id)
  end

  def test_push_subscription_changes
    CRM::FreshsalesUtility.any_instance.stubs(:get_entity_id).returns('1')
    CRM::FreshsalesUtility.any_instance.stubs(:search).returns(deals: [{ deal_product_id: '1', deal_stage_id: '1', sales_account_id: '1' }], id: '1', sales_accounts: [id: '1'], deal_stages: {})
    CRM::FreshsalesUtility.new(cmrr: @account.subscription.cmrr, account: @account, subscription: @account.subscription).push_subscription_changes('deal', 'amount', 'payments_count', 'state_changed')
    assert_equal response.status, 200
  ensure
    CRM::FreshsalesUtility.any_instance.unstub(:search)
    CRM::FreshsalesUtility.any_instance.unstub(:get_entity_id)
  end

  def test_account_trial_expiry
    CRM::FreshsalesUtility.any_instance.stubs(:get_entity_id).returns('1')
    CRM::FreshsalesUtility.any_instance.stubs(:search).returns(deals: [{ deal_product_id: '1', deal_stage_id: '1', sales_account_id: '1' }], id: '1', sales_accounts: [id: '1'], deal_stages: {})
    CRM::FreshsalesUtility.new(cmrr: @account.subscription.cmrr, account: @account, subscription: @account.subscription).account_trial_expiry
    CRM::FreshsalesUtility.any_instance.stubs(:search).returns(deals: [], id: '1', sales_accounts: [id: '1'], deal_stages: {}, leads: [{ deal_product_id: '1' }])
    CRM::FreshsalesUtility.new(cmrr: @account.subscription.cmrr, account: @account, subscription: @account.subscription).account_trial_expiry
    assert_equal response.status, 200
  ensure
    CRM::FreshsalesUtility.any_instance.unstub(:get_entity_id)
    CRM::FreshsalesUtility.any_instance.unstub(:search)
  end

  def test_account_cancellation
    CRM::FreshsalesUtility.any_instance.stubs(:get_entity_id).returns('1')
    CRM::FreshsalesUtility.any_instance.stubs(:update_deal_or_lead).returns(true)
    CRM::FreshsalesUtility.new(cmrr: @account.subscription.cmrr, account: @account, subscription: @account.subscription).account_cancellation
  ensure
    CRM::FreshsalesUtility.any_instance.unstub(:get_entity_id)
    CRM::FreshsalesUtility.any_instance.unstub(:update_deal_or_lead)
  end

  def test_account_trial_extension
    CRM::FreshsalesUtility.any_instance.stubs(:get_entity_id).returns('1')
    CRM::FreshsalesUtility.any_instance.stubs(:update_deal_or_lead).returns(true)
    resp = CRM::FreshsalesUtility.new(cmrr: @account.subscription.cmrr, account: @account, subscription: @account.subscription).account_trial_extension
    assert_equal resp, true
  ensure
    CRM::FreshsalesUtility.any_instance.unstub(:get_entity_id)
    CRM::FreshsalesUtility.any_instance.unstub(:update_deal_or_lead)
  end

  def test_account_manager
    CRM::FreshsalesUtility.any_instance.stubs(:get_entity_id).returns('1')
    CRM::FreshsalesUtility.any_instance.stubs(:search_leads_by_account_and_product).returns(leads: [], deals: [{ deal_product_id: '1', deal_stage_id: '1', sales_account_id: '1' }])
    resp = CRM::FreshsalesUtility.new(cmrr: @account.subscription.cmrr, account: @account, subscription: @account.subscription).account_manager
    assert_equal resp.to_json, { display_name: 'Bobby', email: 'eval@freshdesk.com' }.to_json
  ensure
    CRM::FreshsalesUtility.any_instance.unstub(:search_leads_by_account_and_product)
    CRM::FreshsalesUtility.any_instance.unstub(:get_entity_id)
  end
end
