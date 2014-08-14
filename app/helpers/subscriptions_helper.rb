module SubscriptionsHelper 
  include Subscription::Currencies::Constants

  def get_payment_string(period,amount)
    amount = format_amount(amount, current_account.currency_name)
		if period == SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:annual]
    		return t('amount_billed_annually', :amount => amount ).html_safe 
		end
		return  t('amount_billed_per_month',{:amount => amount,:period => SubscriptionPlan::BILLING_CYCLE_NAMES_BY_KEY[period]}).html_safe
	end
 
	def get_amount_string(period,amount)
		if period == SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:annual]
			return t('amount_for_annual', :amount => amount ).html_safe 
		end
		return  t('amount_per_month',{:amount => amount,:period => SubscriptionPlan::BILLING_CYCLE_NAMES_BY_KEY[period]}).html_safe
	end

    def open_html_tag
    	html_conditions = [ ["lt IE 6", "ie6"],
                        ["IE 7", "ie7"],
                        ["IE 8", "ie8"],
                        ["IE 9", "ie9"],
                        ["IE 10", "ie10"],
                        ["(gt IE 10)|!(IE)", "", true]]

    	html_conditions.map { |h| %( 
	        <!--[if #{h[0]}]>#{h[2] ? '<!-->' : ''}<html class="no-js #{h[1]}" lang="#{ 
	          current_portal.language }">#{h[2] ? '<!--' : ''}<![endif]--> ) }.to_s.html_safe
  	end

  def current_freshfone_balance(freshfone_credit)
  	balance = (freshfone_credit) ? freshfone_credit.available_credit : 0
  	number_to_currency(balance) 
  end

  #Options to be re-written before release
  def recharge_options
    credit_price = current_account.subscription.retrieve_addon_price(:freshfone)
    cost_options = []
    (Freshfone::Credit::RECHARGE_OPTIONS).step(Freshfone::Credit::STEP){ |cost|
      cost_options << [ format_amount((cost * credit_price), current_account.currency_name), cost ]
    }
    cost_options
  end

  def fetch_recharge_amount
    credit_price = current_account.subscription.retrieve_addon_price(:freshfone)
    recharge_price = current_account.freshfone_credit.recharge_quantity * credit_price
    format_amount(recharge_price, current_account.currency_name)
  end

  def fetch_plan_amount(plan)    
    currency = current_account.currency_name
    amount = plan.pricing(currency)
    format_amount(amount, currency)
  end

  def format_amount(amount, currency)    
    number_to_currency(amount, :unit => CURRENCY_UNITS[currency], :separator => ".", 
      :delimiter => ",", :format => "%u%n", :precision => 0)
  end

  def fetch_currency_unit
    CURRENCY_UNITS[current_account.currency_name]
  end

  def fetch_currencies
    options_for_select(BILLING_CURRENCIES, :selected => current_account.currency_name)
  end

  def default_currency?
    current_account.currency_name.eql?(DEFAULT_CURRENCY)
  end

 end