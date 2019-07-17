require_relative '../../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'agents_test_helper.rb')

class Admin::SubscriptionsControllerTest < ActionController::TestCase
  include AccountTestHelper
  include AgentsTestHelper
  
  CHARGEBEE_LIST_PLANS_API_RESPONSE = '{"list":[{"plan":{"id":"sprout_monthly",
    "name":"Sprout Monthly", "invoice_name":"Sprout Monthly 2016","price":1500,
    "period":1,"period_unit":"month","trial_period":30,"trial_period_unit":"day",
    "free_quantity":3,"status":"active"}},{"plan":{"id":
    "estate_quarterly","name":"Estate Quarterly","invoice_name":"Estate Quarterly 2016",
    "price":4900,"period":3,"period_unit":"quarterly","trial_period":30,
    "trial_period_unit":"day","free_quantity":0,"status":"active"}}]}'
  CURRENCY_SYMBOL_MAP = { 'USD' => '$', 'INR' => '₹'}

  def setup
    super
    @currency_map = Hash[Subscription::Currency.all.collect{ |cur| [cur.name, cur] }]
  end

  def wrap_cname(params)
    params
  end
  
  def test_valid_show
    @account = Account.current
    get :show, construct_params(version: 'private')
    assert_response 200
    match_json(subscription_response(@account.subscription))
  end

  def test_show_no_privilege
    stub_admin_tasks_privilege
    get :show, construct_params(version: 'private')
    assert_response 403
    unstub_privilege
  end

  def test_plans_for_account_default_currency
    stub_plans
    get :plans, controller_params(version: 'private')
    assert_response 200
    match_json(plans_response)
    unstub_plans
  end

  def test_plans_with_given_currency_value
    stub_plans('INR')
    get :plans, controller_params(version: 'private', currency: 'INR')
    assert_response 200
    match_json(plans_response('INR'))
    unstub_plans
  end

  def test_plans_for_admin_tasks_privilege
    stub_admin_tasks_privilege
    get :plans, controller_params(version: 'private')
    assert_response 403
    unstub_privilege
  end

  def test_plans_with_invalid_currency
    get :plans, controller_params(version: 'private', currency: 'IN')
    assert_response 400
    match_json([bad_request_error_pattern('currency', :not_included,
      list: Subscription::Currency.currency_names_from_cache.join(','),
      code: :invalid_value)])
  end

  def test_update_subscription
    create_new_account("test123", "test123@freshdesk.com")
    @account.launch(:enable_customer_journey)
    update_currency
    agent = @account.users.where(helpdesk_agent: true).first
    User.stubs(:current).returns(agent)
    @controller.stubs(:api_current_user).returns(User.current)
    @controller.api_current_user.stubs(:privilege?).returns(true)
    updated_features_list = [:split_tickets, :add_watcher, :traffic_cop, :custom_ticket_views, :supervisor, :create_observer, :sla_management, :assume_identity, :rebranding, :custom_apps, :custom_ticket_fields, :custom_company_fields, :custom_contact_fields, :occasional_agent, :allow_auto_suggest_solutions, :basic_twitter, :basic_facebook, :gamification, :auto_refresh, :advanced_twitter, :advanced_facebook, :surveys, :scoreboard, :timesheets, :custom_domain, :multiple_emails, :advanced_reporting, :default_survey, :forums, :css_customization, :sitemap, :multi_language, :dynamic_content, :requester_widget, :ticket_templates, :collision, :mailbox, :branding, :basic_dkim, :link_tickets_toggle, :proactive_outreach, :advanced_search, :system_observer_events, :collaboration, :user_notifications, :quick_reply, :image_annotation, :tam_default_fields, :todos_reminder_scheduler, :google_signin, :twitter_signin, :facebook_signin, :signup_link, :freshchat, :session_replay, :freshconnect, :captcha, :moderate_posts_with_links, :redis_display_id, :survey_links, :anonymous_tickets, :open_solutions, :auto_suggest_solutions, :reply_to_based_tickets, :marketplace, :fa_developer, :contact_company_notes, :reverse_notes, :disable_old_ui, :es_v2_writes, :canned_forms, :agent_scope, :social_tab, :public_url_toggle, :add_to_response, :customize_table_view, :custom_password_policy, :performance_report, :sla_management_v2, :scenario_automation, :ticket_volume_report, :omni_channel, :personal_canned_response, :proactive_spam_detection, :api_v2, :analytics_landing_search, :analytics_landing_navigation, :analytics_report_clone, :analytics_report_filter, :analytics_report_schedule, :analytics_report_export, :analytics_report_presentation_mode, :analytics_report_delete, :analytics_report_save, :analytics_widget_schedule, :analytics_widget_export, :analytics_widget_save, :analytics_widget_change_chart, :analytics_widget_show_tabular_data, :analytics_widget_edit_tabular_data, :analytics_widget_delete, :analytics_agent_performance, :analytics_group_performance, :analytics_helpdesk_in_depth_report, :analytics_ticket_volume_trend, :analytics_time_sheet_summary_report, :analytics_satisfaction_survey_report, :analytics_linked_tracker_ticket, :analytics_child_parent_ticket, :analytics_tags_reports, :analytics_tickets_resource, :analytics_timesheet_resource, :analytics_tags_resource, :article_filters, :adv_article_bulk_actions, :auto_article_order, :social_revamp, :spam_dynamo, :activity_revamp, :customer_journey]
    result = ChargeBee::Result.new(stub_update_params)
    ChargeBee::Subscription.stubs(:update).returns(result)
    @account.subscription.state = 'active'
    @account.subscription.card_number = '12345432'
    # Testing upgrade from sprout/blossom to garden enables customer_journey feature
    assert !@account.features_list.include?(:customer_journey)
    put :update, construct_params({ version: 'private', plan_id: SubscriptionPlan.cached_current_plans.map(&:id).third, agent_seats: 1 }, {})
    @account.reload
    assert_response 200
    assert_equal JSON.parse(response.body)['plan_id'], SubscriptionPlan.cached_current_plans.map(&:id).third
    assert (updated_features_list - @account.features_list).empty?
    put :update, construct_params({ version: 'private', renewal_period: 6 }, {})
    assert_response 200
    #moving to sprout and checking all the validations
    put :update, construct_params({ version: 'private', plan_id: SubscriptionPlan.cached_current_plans.map(&:id).first, renewal_period: 6 }, {})
    assert_equal @account.subscription_plan.renewal_period, 1
    assert_response 200
    put :update, construct_params({ version: 'private', renewal_period: 6 }, {})
    assert_response 400
  ensure
    ChargeBee::Subscription.unstub(:update)
    User.unstub(:current)
    @controller.api_current_user.unstub(:privilege?)
    @account.destroy
  end

  def test_update_subscription_with_trial_state
    account = Account.current
    result = ChargeBee::Result.new(stub_update_params)
    ChargeBee::Subscription.stubs(:update).returns(result)
    account.subscription.state = 'trial'
    put :update, construct_params({ version: 'private', plan_id: 8 }, {})
    assert_response 400
  ensure
    ChargeBee::Subscription.unstub(:update)
  end

  def test_update_subscription_with_suspended_state
    account = Account.current
    result = ChargeBee::Result.new(stub_update_params)
    ChargeBee::Subscription.stubs(:update).returns(result)
    account.subscription.state = 'suspended'
    put :update, construct_params({ version: 'private', plan_id: 8 }, {})
    assert_response 402
  ensure
    ChargeBee::Subscription.unstub(:update)
  end

  def test_update_subscription_with_free_state
    account = Account.current
    result = ChargeBee::Result.new(stub_update_params)
    ChargeBee::Subscription.stubs(:update).returns(result)
    account.subscription.state = 'free'
    put :update, construct_params({ version: 'private', plan_id: 8 }, {})
    assert_response 400
  ensure
    ChargeBee::Subscription.unstub(:update)
  end

  def test_update_susbcription_with_invalid_plan_id
    account = Account.current
    result = ChargeBee::Result.new(stub_update_params)
    ChargeBee::Subscription.stubs(:update).returns(result)
    account.subscription.state = 'active'
    put :update, construct_params({ version: 'private', plan_id: '8' }, {})
    assert_response 400
  ensure
    ChargeBee::Subscription.unstub(:update) 
  end

  def test_update_subscription_with_invalid_renewal_period
    account = Account.current
    result = ChargeBee::Result.new(stub_update_params)
    ChargeBee::Subscription.stubs(:update).returns(result)
    account.subscription.state = 'active'
    put :update, construct_params({ version: 'private', renewal_period: 20 }, {})
    assert_response 400
  ensure
    ChargeBee::Subscription.unstub(:update)
  end

  def test_update_subscription_with_no_card_number
    account = Account.current
    result = ChargeBee::Result.new(stub_update_params)
    ChargeBee::Subscription.stubs(:update).returns(result)
    account.subscription.card_number = nil
    put :update, construct_params({ version: 'private', plan_id: 8 }, {})
    assert_response 400
  ensure
    ChargeBee::Subscription.unstub(:update)
  end

  def test_update_without_valid_plan_id
    account = Account.current
    result = ChargeBee::Result.new(stub_update_params)
    ChargeBee::Subscription.stubs(:update).returns(result)
    account.subscription.state = 'active'
    account.subscription.card_number = '12345432'
    put :update, construct_params({ version: 'private', plan_id: Faker::Number.number(3) }, {})
    assert_response 400
  ensure
    ChargeBee::Subscription.unstub(:update)
  end

  def test_update_with_invalid_agent_seats
    account = Account.current
    result = ChargeBee::Result.new(stub_update_params)
    ChargeBee::Subscription.stubs(:update).returns(result)
    account.subscription.state = 'active'
    account.subscription.card_number = '12345432'
    put :update, construct_params({ version: 'private', plan_id: 8 , agent_seats: '1' }, {})
    assert_response 400
  ensure
    ChargeBee::Subscription.unstub(:update)
  end
  
  def test_subscription_estimate_without_mandatory_params
    get :estimate, controller_params({ version: 'private' }, false)
    assert_response 400
    match_json([bad_request_error_pattern('agent_seats', :missing_field, code: :missing_field),
                bad_request_error_pattern('renewal_period', :missing_field, code: :missing_field)])
  end

  def test_subscription_estimate_with_invalid_agent_seats
    get :estimate, controller_params({ version: 'private', agent_seats: Faker::Lorem.word, renewal_period: 3 }, false)
    assert_response 400
    match_json([bad_request_error_pattern('agent_seats', :datatype_mismatch, expected_data_type: 'Positive Integer')])
  end

  def test_subscription_estimate_with_invalid_renewal_period
    get :estimate, controller_params({ version: 'private', agent_seats: 1, renewal_period: 2 }, false)
    assert_response 400
    match_json([bad_request_error_pattern('renewal_period', :not_included, list: '1,3,6,12')])
  end

  def test_subscription_estimate_with_string_renewal_period
    get :estimate, controller_params({ version: 'private', agent_seats: 3, renewal_period: Faker::Lorem.word }, false)
    assert_response 400
    match_json([bad_request_error_pattern('renewal_period', :datatype_mismatch, expected_data_type: 'Positive Integer')])
  end

  def test_subscription_estimate_with_free_plan
    SubscriptionPlan.any_instance.stubs(:amount).returns(0)
    get :estimate, controller_params({ version: 'private', agent_seats: 1, renewal_period: 12, plan_id: 6 }, false)
    assert_response 400
    bad_request_error_pattern('plan_id', :invalid_plan_id, code: :invalid_value)
  ensure
    SubscriptionPlan.any_instance.unstub(:amount)
  end

  def test_subscription_estimate
    stub_chargebee_requests
    get :estimate, controller_params({ version: 'private', agent_seats: 1, renewal_period: 12, plan_id: SubscriptionPlan.last.id }, false)
    assert_response 200
  ensure
    unstub_chargebee_requests
  end

  private

    def stub_chargebee_requests
      chargebee_subscription = ChargeBee::Subscription.create({
        :plan_id => 'estate_jan_17_monthly',
        :billing_address => {
          :first_name => Faker::Name.first_name,
          :last_name => Faker::Name.last_name,
          :line1 => 'PO Box 9999',
          :city => 'Walnut',
          :state => 'California',
          :zip => '91789',
          :country => 'US'
        },
        :customer => {
          :first_name => Faker::Name.first_name,
          :last_name => Faker::Name.last_name,
          :email => Faker::Internet.email
        }
      })
      chargebee_estimate = ChargeBee::Estimate.create_subscription({
        :billing_address => {
          :line1 => 'PO Box 9999',
          :city => 'Walnut',
          :zip => '91789',
          :country => 'US'
        },
        :subscription => {
          :plan_id => 'estate_jan_17_monthly'
        }
      })
      Subscription.any_instance.stubs(:active?).returns(true)
      Billing::Subscription.any_instance.stubs(:calculate_update_subscription_estimate).returns(chargebee_estimate)
      ChargeBee::Subscription.stubs(:retrieve).returns(chargebee_subscription)
      RestClient::Request.stubs(:execute).returns(immediate_invoice_stub.to_json)
    end

    def unstub_chargebee_requests
      Subscription.any_instance.unstub(:active?)
      Billing::Subscription.any_instance.unstub(:calculate_update_subscription_estimate)
      ChargeBee::Subscription.unstub(:retrieve)
      RestClient::Request.unstub(:execute)
    end

    def mock_plan(id, plan_name)
      mock_subscription_plan = Minitest::Mock.new
      2.times {
        mock_subscription_plan.expect :name, plan_name
        mock_subscription_plan.expect :id, id
      }
      mock_subscription_plan
    end

    def stub_admin_tasks_privilege(manage_tickets = false)
      User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
    end

    def unstub_privilege
      User.any_instance.unstub(:privilege?)
    end

    def chargebee_plans_api_response_stub(currency_code=nil)
      return CHARGEBEE_LIST_PLANS_API_RESPONSE if currency_code.nil?
      currency_based_response = JSON.parse(CHARGEBEE_LIST_PLANS_API_RESPONSE)
      currency_based_response["list"].each do |plans|
        plans["plan"]["currency_code"] = "INR"
      end
      currency_based_response.to_json
    end

    def stub_plans(currency='USD')
      mock_plans = [mock_plan(1, 'Sprout'), mock_plan(20, 'Estate')]
      SubscriptionPlan.stubs(:cached_current_plans).returns(mock_plans)
      SubscriptionPlan.stubs(:current).returns(mock_plans)
      RestClient::Request.stubs(:execute).with({
        method: :get,
        url: "https://#{@currency_map[currency].billing_site}.chargebee.com/api/v2/plans",
        user: @currency_map[currency].billing_api_key,
        headers: {
          params: {
            limit: 100,
            "id[in]": '[sprout_monthly,sprout_quarterly,sprout_half_yearly,sprout_annual,estate_monthly,estate_quarterly,estate_half_yearly,estate_annual]'
          }
        }
      }).returns(chargebee_plans_api_response_stub(currency))
    end

    def unstub_plans
      SubscriptionPlan.unstub(:current)
      RestClient::Request.unstub(:execute)
    end

    def stub_update_params
      {
        'subscription':
          {
            'id': '1', 'plan_id': 'blossom_jan_19_annual',
            'plan_quantity': 1, 'status': 'active', 'trial_start': 1556863974,
            'trial_end': 1556864678, 'current_term_start': 1557818479,
            'current_term_end': 1589440879, 'created_at': 1368442623,
            'started_at': 1368442623, 'activated_at': 1556891503,
            'has_scheduled_changes': false, 'object': 'subscription',
            'coupon': '1FREEAGENT', 'coupons': [{ 'coupon_id': '1FREEAGENT',
            'applied_count': 38, 'object': 'coupon' }], 'due_invoices_count': 0
          },
          'customer': { 'id': '1', 'first_name': 'Ethan hunt',
                        'last_name': 'Ethan hunt', 'email': 'meaghan.bergnaum@kaulke.com',
                        'company': 'freshdesk', 'auto_collection': 'on',
                        'allow_direct_debit': false, 'created_at': 1368442623,
                        'taxability': 'taxable', 'object': 'customer',
                        'billing_address': { 'first_name': 'asdasd', 'last_name': 'asdasasd',
                                             'line1': 'A14, Sree Prasad Apt, Jeswant Nagar, Mugappair West',
                                             'city': 'Chennai', 'state_code': 'TN', 'state': 'Tamil Nadu',
                                             'country': 'IN', 'zip': '600037', 'object': 'billing_address' },
                        'card_status': 'valid',
                        'payment_method': { 'object': 'payment_method', 'type': 'card',
                                            'reference_i': 'tok_HngTopzRQR3BKK1E17', 'gateway': 'chargebee',
                                            'status': 'valid' },
                        'account_credits': 0, 'refundable_credits': 4553100, 'excess_payments': 0,
                        'cf_account_domain': 'aut.freshpo.com', 'meta_data': { 'customer_key': 'fdesk.1' } },
          'card': { 'status': 'valid', 'gateway': 'chargebee', 'first_name': 'sdasd',
                    'last_name': 'asdasd', 'iin': '411111', 'last4': '1111', 'card_type': 'visa',
                    'expiry_month': 12, 'expiry_year': 2020, 'billing_addr1': 'A14, Sree Prasad Apt',
                    'billing_addr2': 'Jeswant Nagar, Mugappair West', 'billing_city': 'Chennai',
                    'billing_state_code': 'TN', 'billing_state': 'Tamil Nadu', 'billing_country': 'IN',
                    'billing_zip': '600037', 'ip_address': '182.73.13.166', 'object': 'card',
                    'masked_number': '************1111', 'customer_id': '1' }
      }
    end

    def plans_response(currency='USD')
      [
          {
              "id": 1,
              "name": "Sprout",
              "currency": currency,
              "pricings": [
                  {
                      "billing_cycle": "monthly",
                      "cost_per_agent": "#{CURRENCY_SYMBOL_MAP[currency]}15"
                  },
                  {
                      "billing_cycle": "quarterly",
                      "cost_per_agent": nil
                  },
                  {
                      "billing_cycle": "half_yearly",
                      "cost_per_agent": nil
                  },
                  {
                      "billing_cycle": "annual",
                      "cost_per_agent": nil
                  }
              ]
          },
          {
              "id": 20,
              "name": "Estate",
              "currency": currency,
              "pricings": [
                  {
                      "billing_cycle": "monthly",
                      "cost_per_agent": nil
                  },
                  {
                      "billing_cycle": "quarterly",
                      "cost_per_agent": "#{CURRENCY_SYMBOL_MAP[currency]}16"
                  },
                  {
                      "billing_cycle": "half_yearly",
                      "cost_per_agent": nil
                  },
                  {
                      "billing_cycle": "annual",
                      "cost_per_agent": nil
                  }
              ]
          }
      ]
    end

    def subscription_response(subscription)
      {
        'id': subscription.id,
        'state': subscription.state,
        'plan_id': subscription.subscription_plan_id,
        'renewal_period': subscription.renewal_period,
        'agent_seats': subscription.agent_limit,
        'card_number': subscription.card_number,
        'card_expiration': subscription.card_expiration,
        'name_on_card': (subscription.billing_address.name_on_card if subscription.billing_address.present?),
        'updated_at': %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
        'created_at': %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
        'currency': subscription.currency.name,
        'addons': nil
      
      }
    end

    def immediate_invoice_stub
      {
        'estimate' => {
          'created_at' =>1559284330,
          'object' => 'estimate',
          'subscription_estimate' => {
            'id' =>'1',
            'status' =>'active',
            'next_billing_at' =>1561876330,
            'object' =>'subscription_estimate',
            'currency_code' =>'USD'
          },
          'invoice_estimate' => {
            'recurring' => true,
            'date' => 1559284330,
            'price_type' => 'tax_exclusive',
            'sub_total' => 5900,
            'total' => 6200,
            'credits_applied' => 6200,
            'amount_paid' => 0,
            'amount_due' => 0,
            'object' => 'invoice_estimate',
            'line_items' => [{
              'id' => 'li_1mbDWbrRS1m8ql2PRG',
              'date_from' => 1559284330,
              'date_to' => 1561876330,
              'unit_amount' => 5900,
              'quantity' => 2,
              'amount' => 11800,
              'pricing_model' => 'per_unit',
              'is_taxed' => true,
              'tax_amount' => 295,
              'tax_rate' => 5.0,
              'object' => 'line_item',
              'subscription_id' =>'1',
              'customer_id' => '1',
              'description' => 'Estate Monthly plan',
              'entity_type' => 'plan',
              'entity_id' => 'estate_jan_17_monthly',
              'discount_amount' => 5900,
              'item_level_discount_amount' => 5900
            }],
            'discounts' => [{
              'object' => 'discount',
              'entity_type' => 'item_level_coupon',
              'description' => '1 free agent',
              'amount' => 5900,
              'entity_id' => '1FREEAGENT'
            }],
            'taxes' => [{
              'object' => 'tax',
              'name' => 'IND TAX',
              'description' => 'IND TAX @ 5%',
              'amount' => 295
            }],
            'line_item_taxes' => [{
              'tax_name' => 'IND TAX',
              'tax_rate' => 5.0,
              'tax_juris_type' => 'country',
              'tax_juris_name' => 'India',
              'tax_juris_code' => 'IN',
              'object' => 'line_item_tax',
              'line_item_id' => 'li_1mbDWbrRS1m8ql2PRG',
              'tax_amount' => 295,
              'is_partial_tax_applied' => false,
              'taxable_amount' => 5900,
              'is_non_compliance_tax' => false
            }],
            'currency_code' => 'USD',
            'round_off_amount' => 5,
            'line_item_discounts' => [{
              'object' => 'line_item_discount',
              'line_item_id' => 'li_1mbDWbrRS1m8ql2PRG',
              'discount_type' => 'item_level_coupon',
              'discount_amount' => 5900,
              'coupon_id' => '1FREEAGENT'
            }]
          },
         'credit_note_estimates' => [{
            'reference_invoice_id' =>  '133811',
            'type' =>  'refundable',
            'price_type' =>  'tax_exclusive',
            'sub_total' =>  0,
            'total' =>  0,
            'amount_allocated' =>  0,
            'amount_available' =>  0,
            'object' =>  'credit_note_estimate',
            'line_items' => [{
              'id' =>  'li_1mbDWbrRS1m8qX2PRB',
              'date_from' =>  1559284330,
              'date_to' =>  1575095388,
              'unit_amount' =>  35400,
              'quantity' =>  1,
              'amount' =>  35400,
              'pricing_model' =>  'per_unit',
              'is_taxed' =>  true,
              'tax_amount' =>  0,
              'tax_rate' =>  5.0,
              'object' =>  'line_item',
              'subscription_id' =>  '1',
              'description' =>  'Estate Half yearly plan - Prorated Credits for 31-May-2019 - 30-Nov-2019',
              'entity_type' =>  'plan',
              'entity_id' =>  'estate_jan_17_half_yearly',
              'discount_amount' =>  35400,
              'item_level_discount_amount' =>  35400
            }],
            'discounts' => [{
              'object' => 'discount',
              'entity_type' => 'item_level_coupon',
              'description' => '1 free agent',
              'amount' => 35400,
              'entity_id' => '1FREEAGENT'
            }],
            'taxes' => [{
              'object' => 'tax',
              'name' => 'IND TAX',
              'description' => 'IND TAX @ 5%',
              'amount' => 0
            }],
            'line_item_taxes' => [{
              'tax_name' => 'IND TAX',
              'tax_rate' => 5.0,
              'tax_juris_type' => 'country',
              'tax_juris_name' => 'India',
              'tax_juris_code' => 'IN',
              'object' => 'line_item_tax',
              'line_item_id' => 'li_1mbDWbrRS1m8qX2PRB',
              'tax_amount' => 0,
              'is_partial_tax_applied' => false,
              'taxable_amount' => 0,
              'is_non_compliance_tax' => false
            }],
           'currency_code' => 'USD',
           'round_off_amount' => 0,
           'line_item_discounts' => [{
              'object' => 'line_item_discount',
              'line_item_id' => 'li_1mbDWbrRS1m8qX2PRB',
              'discount_type' => 'item_level_coupon',
              'discount_amount' => 35400,
              'coupon_id' => '1FREEAGENT'
            }]
          },
          {
            'reference_invoice_id' => '133812',
            'type' => 'refundable',
            'price_type' => 'tax_exclusive',
            'sub_total' => 35400,
            'total' => 37200,
            'amount_allocated' => 0,
            'amount_available' => 37200,
            'object' => 'credit_note_estimate',
            'line_items' => [{
              'id' => 'li_1mbDWbrRS1m8qF2PR9',
              'date_from' => 1559284330,
              'date_to' => 1575095388,
              'unit_amount' => 35400,
              'quantity' => 1,
              'amount' => 35400,
              'pricing_model' => 'per_unit',
              'is_taxed' => true,
              'tax_amount' => 1770,
              'tax_rate' => 5.0,
              'object' => 'line_item',
              'subscription_id' => '1',
              'description' => 'Estate Half yearly plan - Prorated Credits for 31-May-2019 - 30-Nov-2019',
              'entity_type' => 'plan',
              'entity_id' => 'estate_jan_17_half_yearly',
              'discount_amount' => 0,
              'item_level_discount_amount' => 0
            }],
            'taxes' => [{
              'object' => 'tax',
              'name' => 'IND TAX',
              'description' => 'IND TAX @ 5%',
              'amount' => 1770
            }],
            'line_item_taxes' => [{
              'tax_name' => 'IND TAX',
              'tax_rate' => 5.0,
              'tax_juris_type' => 'country',
              'tax_juris_name' => 'India',
              'tax_juris_code' => 'IN',
              'object' => 'line_item_tax',
              'line_item_id' => 'li_1mbDWbrRS1m8qF2PR9',
              'tax_amount' => 1770,
              'is_partial_tax_applied' => false,
              'taxable_amount' => 35400,
              'is_non_compliance_tax' => false
            }],
            'currency_code' => 'USD',
            'round_off_amount' => 30,
            'line_item_discounts' => []
          }]
        }
      }
    end
end
