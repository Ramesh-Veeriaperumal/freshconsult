module AccountsHelper 
  
  def get_payment_string(period,amount)
   if period == SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:annual]
    return t('billed_amount_annually', :amount => amount ) 
   end
   return  t('billed_amount_per_month',{:amount => amount,:period => SubscriptionPlan::BILLING_CYCLE_NAMES_BY_KEY[period]})
  end
  
end
