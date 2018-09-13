require_relative '../../test_helper'
class Admin::SubscriptionsControllerTest < ActionController::TestCase
  
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
  
  def test_vaild_show
    get :show, construct_params(version: 'private')
    assert_response 200
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

  private

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
end