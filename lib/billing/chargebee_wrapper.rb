class Billing::ChargebeeWrapper

	CHARGEBEE_REST_URL = "https://%{subdomain}.chargebee.com/api/v2/%{resource_type}".freeze
	PRODUCT_NAME       = 'fdesk'.freeze
  DAY_PASS_CALC      = 'Daypass recalculation'.freeze
  CB_RESOURCES       = {
                          plans: 'plans',
                          add_credits: 'promotional_credits/add',
                          estimate_update: 'estimates/update_subscription',
                          estimate_create: 'estimates/create_subscription'
                       }.freeze

	def initialize
    subscription = Account.current.subscription
    ChargeBee.configure(:site => subscription.currency_billing_site, 
                        :api_key => subscription.currency_billing_api_key)
  end

  #subscription
	def create_subscription(data)
		Rails.logger.debug ":::ChargeBee - Create Subscription - Params sent:::"
		Rails.logger.debug data.inspect
		ChargeBee::Subscription.create(data)
		update_customer(Account.current.id, {})
	end

	def update_subscription(account_id, data)
		Rails.logger.debug ":::ChargeBee - Update Subscription - Params sent:::"
		Rails.logger.debug data.inspect
		ChargeBee::Subscription.update(account_id, data)
	end

	def activate_subscription(account_id)
		ChargeBee::Subscription.update(account_id, :trial_end => 0)
	end

	def cancel_subscription(account_id, data = {})
		ChargeBee::Subscription.cancel(account_id, data)
	end

	def reactivate_subscription(account_id, data = {})
		ChargeBee::Subscription.reactivate(account_id, data)
	end

	def retrieve_subscription(account_id)
		ChargeBee::Subscription.retrieve(account_id)
	end

	def remove_scheduled_changes(account_id)
		ChargeBee::Subscription.remove_scheduled_changes(account_id)
	end

	#estimate
	def create_subscription_estimate(data)
		Rails.logger.debug ":::ChargeBee - Create Subscription Estimate - Params sent:::"
		Rails.logger.debug data.inspect
		ChargeBee::Estimate.create_subscription(data)
	end

	def update_subscription_estimate(data)
		Rails.logger.debug ":::ChargeBee - Update Subscription Estimate - Params sent:::"
		Rails.logger.debug data.inspect
		ChargeBee::Estimate.update_subscription(data)
	end

	#card
	def add_card(account_id, data)
		ChargeBee::Card.update_card_for_customer(account_id, data)
	end

	def remove_credit_card(account_id)
    ChargeBee::Card.delete_card_for_customer(account_id)
  end

	def update_non_recurring_addon(data)
		ChargeBee::Invoice.charge_addon(data)
	end

	def retrieve_addon(addon_name)		
		ChargeBee::Addon.retrieve(addon_name.to_s)
	end

	#other
	def update_customer(account_id, data)
		data[:meta_data] = { :customer_key => "#{PRODUCT_NAME}.#{Account.current.id}" }.to_json # update for existing customers
		data[:cf_account_domain] = Account.current.full_domain
		ChargeBee::Customer.update(account_id, data)
	end

	def add_discount(account_id, discount_code)
		ChargeBee::Subscription.update(account_id, :coupon => discount_code)
	end

	def retrieve_plan(billing_plan_name)
		ChargeBee::Plan.retrieve(billing_plan_name)
	end

	def retrieve_coupon(coupon_code)
		ChargeBee::Coupon.retrieve(URI.encode(coupon_code))
	end

	def update_payment_method(account_id)
		ChargeBee::HostedPage.update_payment_method({:iframe_messaging => true, :embed => true, :customer => {:id => account_id}})
	end

	def retrieve_invoice_pdf_url(invoice_id)
		ChargeBee::Invoice.pdf(invoice_id).download.download_url
	end

	def retrieve_plans_by_id(plan_ids, subdomain, api_key)
		url = format(CHARGEBEE_REST_URL, subdomain: subdomain, resource_type: CB_RESOURCES[:plans])
		JSON.parse(RestClient::Request.execute({
		 	method: :get, 
			url: url, 
			user: api_key, 
			headers: { 
				params: { 
					limit: 100,
					"id[in]": "[#{plan_ids.join(',')}]"
				}
			}
		}))["list"].collect{ |list| list["plan"].symbolize_keys! }
	end

  def add_daypass_credits(amount_to_be_added)
    url = format(CHARGEBEE_REST_URL, subdomain: currency.billing_site, resource_type: CB_RESOURCES[:add_credits])
    JSON.parse(RestClient::Request.execute(build_rest_format(url, credits_params(amount_to_be_added))))
  end

	def change_term_end(account_id, data)
		Rails.logger.debug ":::ChargeBee - Change Term End - Params sent:::"
		Rails.logger.debug data.inspect
		ChargeBee::Subscription.change_term_end(account_id, data)
	end

  def retrieve_estimate_content(subscription, addon_data)
    cb_resource_type = subscription.active? ? CB_RESOURCES[:estimate_update] : CB_RESOURCES[:estimate_create]
    url = format(CHARGEBEE_REST_URL, subdomain: subscription.currency.billing_site, resource_type: cb_resource_type)
    JSON.parse(RestClient::Request.execute(build_rest_format(url, estimate_params(subscription, addon_data))))['estimate']
  end

  private
    def credits_params(amount_to_be_added)
      { 
        customer_id: Account.current.id,
        amount: amount_to_be_added*100,
        description: DAY_PASS_CALC
      }
    end

    def estimate_params(subscription, addon_data)
      subscription_plan = "#{subscription.subscription_plan.canon_name}_#{Billing::Subscription::BILLING_PERIOD[subscription.renewal_period]}"
      ret_hash = {
        'billing_cycles' => 1,
        'subscription[plan_id]' => subscription_plan,
        'subscription[plan_quantity]' => subscription.agent_limit,
        'addon[id]' => addon_data[:ids],
        'addon[quantity]' => addon_data[:quantity]
      }
      if subscription.free?
        ret_hash['subscription[trial_end]'] = 0
      else
        ret_hash['subscription[id]'] = subscription.account_id
      end
      ret_hash
    end

    def build_rest_format(url, params, req_type = :post)
      {
        method: req_type, 
        url: url, 
        user: currency.billing_api_key, 
        headers: { 
          params: params
        }
      }
    end

    def currency
      @currency ||= Account.current.subscription.currency
    end

end
