module SubscriptionsHelper 
	def get_payment_string(period,amount)
		if period == SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:annual]
    		return t('billed_amount_annually', :amount => amount ).html_safe 
		end
		return  t('billed_amount_per_month',{:amount => amount,:period => SubscriptionPlan::BILLING_CYCLE_NAMES_BY_KEY[period]}).html_safe
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
 end