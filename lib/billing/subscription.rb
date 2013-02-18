class Billing::Subscription 

  BILLING_PERIOD  = { 1 => "_monthly", 3 => "_quarterly", 6 => "_half_yearly", 12 => "_annual" }

  #dummy card for initial testing
  CREDITCARD_INFO = { :number => "4111111111111111", :expiry_month => 5.months.from_now.month, 
                      :expiry_year => 5.years.from_now.year, :gateway => "chargebee" }   

  ADDRESS_INFO    = { :first_name => :first_name, :last_name => :last_name, :billing_addr1 => :address1, 
                      :billing_addr2 => :address2, :billing_city => :city, :billing_state => :state, 
                      :billing_country => :country, :billing_zip => :zip }

  TRIAL_PLAN_QUANTITY = "1"

  TRIAL_END = "0"

  VALID_CARD = "valid"


  def initialize
    ChargeBee.configure(:site => AppConfig['chargebee'][RAILS_ENV]['site'],
                        :api_key => AppConfig['chargebee'][RAILS_ENV]['api_key'])
  end

  def create_subscription(account)
    ChargeBee::Subscription.create(account_info(account))
  end

  def update_subscription(subscription, prorate)
    data = (subscription_data(subscription)).merge({ :prorate => prorate })
    ChargeBee::Subscription.update(subscription.account_id, data) if has_valid_card?(subscription.account)
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
    begin
      ChargeBee::Subscription.cancel(account_id)
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
    end
  end

  
  private

    def account_info(account)
      {
        :id => account.id,
        :customer => customer_data(account),
        :plan_id => plan_code(account),
        :plan_quantity => TRIAL_PLAN_QUANTITY
      }
    end
    
    def customer_data(account)
      {
        :first_name => account.account_admin.name,
        :email => %(vijayaraj+#{account.id}@freshdesk.com),  #account.account_admin.email,  
        :company => %(#{account.name} (#{account.full_domain}))
      }
    end
    
    def subscription_data(subscription)
      { 
        :plan_id => plan_code(subscription.account), 
        :plan_quantity => subscription.agent_limit 
      }
    end

    def plan_code(account)
      (account.plan_name.to_s).concat(BILLING_PERIOD[account.subscription.renewal_period])
    end

    def has_valid_card?(account)
      ChargeBee::Subscription.retrieve(account.id).customer.card_status.eql?(VALID_CARD)
    end

    def billing_address(subscription)
      address_attributes = ADDRESS_INFO.inject({}) { |h, (k, v)| h[k] = subscription.billing_address.send(v); h }
    end

    def add_on_data(day_pass_purchase)
      { 
        :subscription_id => day_pass_purchase.account_id,
        :addon_id => day_pass_purchase.account.plan_name.to_s, 
        :addon_quantity => day_pass_purchase.quantity_purchased 
      }
    end

end