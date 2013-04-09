class Billing::Subscription

  CREDITCARD_INFO = { :number => :number, :expiry_month => :month, :expiry_year => :year }   

  ADDRESS_INFO    = { :first_name => :first_name, :last_name => :last_name, :billing_addr1 => :address1, 
                      :billing_addr2 => :address2, :billing_city => :city, :billing_state => :state, 
                      :billing_country => :country, :billing_zip => :zip }

  TRIAL_PLAN_QUANTITY = "1"

  TRIAL_END = "0"

  VALID_CARD = "valid"

  PLANS = [ :basic, :pro, :premium, :sprout_classic, :blossom_classic, :garden_classic, :estate_classic, 
            :sprout, :blossom, :garden, :estate ]

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
    data = account_info(account).merge(subscription_info(account.subscription))
    
    ChargeBee::Subscription.create(data)
  end

  def calculate_estimate(subscription)
    data = subscription_data(subscription).merge(:id => subscription.account_id) 

    ChargeBee::Estimate.update_subscription(:subscription => data)
  end

  def update_subscription(subscription, prorate)
    data = (subscription_data(subscription)).merge({ :prorate => prorate })
    
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
    ChargeBee::Invoice.charge_addon( add_on_data(account, quantity) )                                           
  end

  def delete_subscription(account)
    begin
      ChargeBee::Subscription.cancel(account.id)
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
    end
  end

  
  private

    def account_info(account)
      {
        :id => account.id,
        :customer => customer_data(account)
      }
    end
    
    def customer_data(account)
      {
        :first_name => account.admin_first_name,
        :last_name => account.admin_last_name,
        :email =>  %(vijayaraj+#{account.id}@freshdesk.com), # account.admin_email,
        :company => account.name
      }
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

    def has_valid_card?(account)
      ChargeBee::Subscription.retrieve(account.id).customer.card_status.eql?(VALID_CARD)
    end

    def card_info(card)
      CREDITCARD_INFO.inject({}) { |h, (k, v)| h[k] = card.send(v); h }
    end

    def billing_address(address)
       ADDRESS_INFO.inject({}) { |h, (k, v)| h[k] = address.send(v); h }
    end

    def add_on_data(account, quantity)
      { 
        :subscription_id => account.id,
        :addon_id => account.plan_name.to_s, 
        :addon_quantity => quantity
      }
    end

end