class Billing::Subscription

  CUSTOMER_INFO   = { :first_name => :admin_first_name, :last_name => :admin_last_name, 
                       :company => :name }

  CREDITCARD_INFO = { :number => :number, :expiry_month => :month, :expiry_year => :year,
                      :cvv => :verification_value }   

  ADDRESS_INFO    = { :first_name => :first_name, :last_name => :last_name, :billing_addr1 => :address1, 
                      :billing_addr2 => :address2, :billing_city => :city, :billing_state => :state, 
                      :billing_country => :country, :billing_zip => :zip }

  TRIAL_PLAN_QUANTITY = "1"

  TRIAL_END = "0"

  PLANS = [ :sprout, :blossom, :garden, :estate, :sprout_classic, :blossom_classic, :garden_classic,
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

  #constructor
  def initialize
    ChargeBee.configure(:site => AppConfig['chargebee'][RAILS_ENV]['site'],
                        :api_key => AppConfig['chargebee'][RAILS_ENV]['api_key'])
  end

  #instance methods
  def create_subscription(account)
    data = account_info(account).merge(subscription_data(account.subscription))
    
    begin
      ChargeBee::Subscription.create(data)
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
      FreshdeskErrorsMailer.deliver_error_email(nil, nil, e,
        { :subject => "Error creating account in ChargeBee. Account Id - #{account.id}" }) if Rails.env.production?
    end
  end

  def calculate_estimate(subscription, addons)
    data = subscription_data(subscription).merge(:id => subscription.account_id) 
    merge_addon_data(data, subscription, addons)
    attributes = subscription.suspended? ? { :subscription => data } : 
                                { :subscription => data, :end_of_term => true }
    attributes.merge!(:replace_addon_list => true)

    Rails.logger.debug ":::ChargeBee - Calculate Estimate - Params sent:::"
    Rails.logger.debug attributes.inspect
    ChargeBee::Estimate.update_subscription(attributes)    
  end

  def update_subscription(subscription, prorate, addons)
    data = (subscription_data(subscription)).merge({ :prorate => prorate })
    merge_trial_end(data, subscription)
    merge_addon_data(data, subscription, addons)
    data.merge!(:replace_addon_list => true)

    Rails.logger.debug ":::ChargeBee - Update Subscription - Params sent:::"
    Rails.logger.debug data.inspect
    ChargeBee::Subscription.update(subscription.account_id, data)
  end

  def store_card(card, address, subscription)
    card_info = card_info(card).merge(billing_address(address))
    ChargeBee::Card.update_card_for_customer(subscription.account.id, card_info)
  end 

  def activate_subscription(subscription)
    data = subscription_data(subscription).merge( :trial_end => TRIAL_END )
    ChargeBee::Subscription.update(subscription.account_id, data)
  end 

  def update_admin(config)
    ChargeBee::Customer.update(config.account_id, customer_data(config.account))
  end

  def buy_day_passes(account, quantity)
    ChargeBee::Invoice.charge_addon( day_pass_data(account, quantity) )  
  end

  def purchase_freshfone_credits(account, quantity)
    ChargeBee::Invoice.charge_addon( freshfone_addon(account, quantity) )                                         
  end

  def remove_credit_card(account_id)
    ChargeBee::Card.delete_card_for_customer(account_id)
  end

  def cancel_subscription(account)
    account.active? ? ChargeBee::Subscription.cancel(account.id) : true
  end

  def retrieve_subscription(account_id)
    ChargeBee::Subscription.retrieve(account_id)
  end

  def add_discount(account, discount_code)
    ChargeBee::Subscription.update(account.id, :coupon => discount_code)
  end

  def offline_subscription?(account_id)
    retrieve_subscription(account_id).customer.auto_collection.eql?("off")
  end
  
  private

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
      return subscription.next_renewal_at.to_i if subscription.trial? and subscription.next_renewal_at > Time.now
        
      1.hour.from_now.to_i if subscription.suspended? and subscription.card_number.blank?
    end

end