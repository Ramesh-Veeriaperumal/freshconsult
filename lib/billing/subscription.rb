class Billing::Subscription 

  #$CHARGEBEE_DOMAIN = "testcb.com"
  
  PLAN_CODES  = { :Sprout =>  { 1 => "sprout_monthly", 3 => "sprout_quarterly", 
                                6 => "sprout_half_yearly", 12 => "sprout_annual" },

                  :Blossom => { 1 => "blossom_monthly", 3 => "blossom_quarterly",  
                                6 => "blossom_half_yearly", 12 => "blossom_annual" },

                  :Garden =>  { 1 => "garden_monthly", 3 => "garden_quarterly",  
                                6 => "garden_half_yearly", 12 => "garden_annual" },

                  :Estate =>  { 1 => "estate_monthly", 3 => "estate_quarterly",  
                                6 => "estate_half_yearly", 12 => "estate_annual" }, 

                  :Basic =>   { 1 => "basic_monthly", 3 => "basic_quarterly", 
                                6 => "basic_half_yearly", 12 => "basic_annual" },

                  :Pro =>     { 1 => "pro_monthly", 3 => "pro_quarterly", 
                                6 => "pro_half_yearly", 12 => "pro_annual" },

                  :Premium => { 1 => "premium_monthly", 3 => "premium_quarterly", 
                                6 => "premium_half_yearly", 12 => "premium_annual" } }

  DAY_PASSES  = { :Sprout => "sprout", :Blossom => "blossom", :Garden => "garden", :Estate => "estate",
                    :Basic => "basic", :Pro => "pro", :Premium => "premium" }

  
  #dummy card for initial testing
  CREDITCARD_INFO = { :number => "4111111111111111", :expiry_month => 5.months.from_now.month, 
                      :expiry_year => 5.years.from_now.year, :gateway => "chargebee" }   

  ADDRESS_INFO    = { :first_name => :first_name, :last_name => :last_name, :billing_addr1 => :address1, 
                      :billing_addr2 => :address2, :billing_city => :city, :billing_state => :state, 
                      :billing_country => :country, :billing_zip => :zip }

  TRIAL_PLAN_QUANTITY = "2"

  TRIAL_END = "0"


  def initialize
    ChargeBee.configure(:site => AppConfig['chargebee'][RAILS_ENV]['site'],
                        :api_key => AppConfig['chargebee'][RAILS_ENV]['api_key'])
  end

  def create_subscription(account)
    data = subscription_data(account.subscription)
    data.merge!( { :plan_quantity => TRIAL_PLAN_QUANTITY, :customer => customer_data(account) } )
    
    ChargeBee::Subscription.create(data)
  end

  def update_subscription(subscription, prorate)
    data = (subscription_data(subscription)).merge({ :prorate => prorate })
    ChargeBee::Subscription.update(subscription.account_id, data)
  end 

  def store_card(subscription)
    card_info = CREDITCARD_INFO.merge(billing_address(subscription))
    ChargeBee::Card.update_card_for_customer(subscription.account.id, card_info)
  end

  def activate_subscription(subscription)
    ChargeBee::Subscription.update(subscription.account_id, { :trial_end => TRIAL_END })
  end

  def update_admin(user)
    ChargeBee::Customer.update(user.account_id, customer_data(user.account))
  end

  def buy_day_passes(day_pass_purchase)
    ChargeBee::Invoice.charge_addon( add_on_data(day_pass_purchase) )                                           
  end

  def delete_subscription(account_id)
    ChargeBee::Subscription.cancel(account_id)
  end

  
  private

    def customer_data(account)
      {
        :first_name => account.account_admin.name,
        :email => %(vijayaraj+#{account.id}@freshdesk.com),  #account.account_admin.email,  
        :company => account.name
      }
    end

    def subscription_data(subscription)
      { 
        :id => subscription.account_id,
        :plan_id => plan_code(subscription), 
        :plan_quantity => subscription.agent_limit 
      }
    end

    def plan_code(subscription)
      plan = subscription.subscription_plan.name.to_sym
      PLAN_CODES[plan][subscription.renewal_period]
    end

    def billing_address(subscription)
      address_attributes = ADDRESS_INFO.inject({}) { |h, (k, v)| h[k] = subscription.billing_address.send(v); h }
    end

    def add_on_data(day_pass_purchase)
      plan = day_pass_purchase.account.subscription_plan.name.to_sym
      add_on_attributes = { :subscription_id => day_pass_purchase.account.subscription.id,
                            :addon_id => DAY_PASSES[plan], 
                            :addon_quantity => day_pass_purchase.quantity_purchased }
    end

end