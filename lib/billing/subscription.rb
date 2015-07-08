class Billing::Subscription < Billing::ChargebeeWrapper

  CUSTOMER_INFO   = { :first_name => :admin_first_name, :last_name => :admin_last_name, 
                       :company => :name }

  CREDITCARD_INFO = { :number => :number, :expiry_month => :month, :expiry_year => :year,
                      :cvv => :verification_value }   

  ADDRESS_INFO    = { :first_name => :first_name, :last_name => :last_name, :billing_addr1 => :address1, 
                      :billing_addr2 => :address2, :billing_city => :city, :billing_state => :state, 
                      :billing_country => :country, :billing_zip => :zip }

  TRIAL_PLAN_QUANTITY = "1"

  TRIAL_END = "0"

  PLANS = [ :sprout, :blossom, :garden, :estate, :forest, :sprout_classic, :blossom_classic, :garden_classic,
            :estate_classic, :basic, :pro, :premium ]

  BILLING_PERIOD  = { 1 => "monthly", 3 => "quarterly", 6 => "half_yearly", 12 => "annual" }

  MAPPED_PLANS = Array.new

  PLANS.map { |plan|
    BILLING_PERIOD.each do |months, cycle_name|
      MAPPED_PLANS << [ %{#{plan}_#{cycle_name}}, plan.to_s, months ]
    end
  }  # [ [ "sprout_annual", "sprout", 12 ], ... ]


  #class methods
  def self.helpkit_plan
    Hash[*MAPPED_PLANS.map { |i| [i[0], i[1]] }.flatten]
  end

  def self.billing_cycle
    Hash[*MAPPED_PLANS.map { |i| [i[0], i[2]] }.flatten]
  end

  #instance methods
  def create_subscription(account, subscription_params = {})
    data = create_subscription_params(account, subscription_params)
    super(data)
  end

  def update_subscription(subscription, prorate, addons)
    data = (subscription_data(subscription)).merge({ :prorate => prorate })
    merge_trial_end(data, subscription)
    merge_addon_data(data, subscription, addons)
    data.merge!(:replace_addon_list => true)

    super(subscription.account_id, data)
  end

  #estimate
  def calculate_estimate(subscription, addons, discount)
    data = create_estimate_params(subscription, addons, discount)
    create_subscription_estimate(data)
  end

  def calculate_update_subscription_estimate(subscription, addons)
    data = subscription_data(subscription).merge(:id => subscription.account_id) 
    merge_addon_data(data, subscription, addons)
    attributes = cancelled_subscription?(subscription.account_id) ? { :subscription => data } : 
                                { :subscription => data, :end_of_term => true }
    attributes.merge!(:replace_addon_list => true)
    
    update_subscription_estimate(attributes)
  end

  def activate_subscription(subscription, address_details)
    data = subscription_data(subscription).merge( :trial_end => TRIAL_END )
    data = data.merge(address_details)
    ChargeBee::Subscription.update(subscription.account_id, data)
  end 

  def update_admin(config)    
    update_customer(config.account_id, customer_data(config.account))
  end

  def buy_day_passes(account, quantity)
    update_non_recurring_addon(day_pass_data(account, quantity))
  end

  def purchase_freshfone_credits(account, quantity)
    update_non_recurring_addon(freshfone_addon(account, quantity))    
  end  

  def cancel_subscription(account)
    cancelled_subscription?(account.id) ? true : super(account.id) 
  end

  def reactivate_subscription(subscription, data = {})
    ChargeBee::Subscription.reactivate(subscription.account_id, data)
  end

  def add_discount(account, discount_code)
    super account.id, discount_code
  end

  def offline_subscription?(account_id)
    retrieve_subscription(account_id).customer.auto_collection.eql?("off")
  end

  def cancelled_subscription?(account_id)
    retrieve_subscription(account_id).subscription.status.eql?("cancelled")
  end
  
  def retrieve_plan(plan_name, renewal_period = 1)
    billing_plan_name = %(#{plan_name.gsub(' ','_').to_s.downcase}_#{BILLING_PERIOD[renewal_period]})
    super billing_plan_name
  end

  def subscription_exists?(account_id)
    begin
      retrieve_subscription(account_id)
      true
    rescue ChargeBee::APIError => error
      return false if error.http_code == 404
      NewRelic::Agent.notice_error(error)      
    end
  end

  # API to check if coupon can be applied to a plan and max redemptions have not reached.
  def coupon_applicable?(subscription, coupon_code)
    begin
      result = retrieve_coupon(coupon_code)
      coupon = JSON.parse(result.coupon.to_json)["values"]

      return true if applicable_to_plan?(coupon, subscription) and can_be_redeemed?(coupon)      
      false
    rescue ChargeBee::APIError => error
      return false if error.http_code == 404
      NewRelic::Agent.notice_error(error)
    end
  end
  
  private
    def create_subscription_params(account, subscription_params)
      subscription_info = if subscription_params
        subscription_data(account.subscription).merge(subscription_params)
      else
        subscription_data(account.subscription)
      end
      account_info(account).merge(subscription_info)
    end

    def account_info(account)
      {
        :id => account.id,
        :customer => customer_data(account)
      }
    end
    
    def customer_data(account)
      data = CUSTOMER_INFO.inject({}) { |h, (k, v)| h[k] = account.send(v); h }
      data.merge(:email => account.invoice_emails.first)
    end
    
    def subscription_data(subscription)
      { 
        :plan_id => plan_code(subscription), 
        :plan_quantity => subscription.agent_limit.blank? ? TRIAL_PLAN_QUANTITY : subscription.agent_limit
      }
    end

    def plan_code(subscription)
      %{#{subscription.subscription_plan.canon_name.to_s}_#{BILLING_PERIOD[subscription.renewal_period]}}
    end

    def card_info(card)
      CREDITCARD_INFO.inject({}) { |h, (k, v)| h[k] = card.send(v); h }
    end

    def billing_address(address)
       ADDRESS_INFO.inject({}) { |h, (k, v)| h[k] = address.send(v); h }
    end

    def day_pass_data(account, quantity)
      { 
        :subscription_id => account.id,
        :addon_id => account.plan_name.to_s, 
        :addon_quantity => quantity
      }
    end

    def freshfone_addon(account, quantity)
      { 
        :subscription_id => account.id,
        :addon_id => "freshfonecredits", 
        :addon_quantity => quantity
      }
    end

    def addon_billing_params(subscription, addon)
      data = { :id => addon.billing_addon_id }
      data.merge!(:quantity => addon.billing_quantity(subscription)) if addon.billing_quantity(subscription)
      data
    end

    def merge_addon_data(data, subscription, addons)
      addon_list = addons.inject([]) { |a, addon| a << addon_billing_params(subscription, addon) }
      data.merge!(:addons => addon_list)
    end

    def merge_trial_end(data, subscription)
      extend_trial(subscription) ? data.merge!(:trial_end => extend_trial(subscription)) : data
    end

    def extend_trial(subscription)
      return retrieve_subscription(subscription.account_id).subscription.trial_end if subscription.trial? and subscription.next_renewal_at > Time.now
        
      1.hour.from_now.to_i if subscription.suspended? and subscription.card_number.blank?
    end

    def create_estimate_params(subscription, addons, discount)
      data = subscription_data(subscription)
      merge_addon_data(data, subscription, addons)
      data.merge!(:coupon => discount)      
      { :subscription => data, :end_of_term => true, :replace_addon_list => true }
    end

    def applicable_to_plan?(coupon, subscription)
      coupon["plan_ids"].blank? or coupon["plan_ids"].include?(plan_code(subscription))
    end

    def can_be_redeemed?(coupon)
      coupon["max_redemptions"].to_i.eql?(0) or 
        coupon["max_redemptions"].to_i > coupon["redemptions"].to_i
    end
    
end