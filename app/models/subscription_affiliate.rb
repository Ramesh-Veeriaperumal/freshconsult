class SubscriptionAffiliate < ActiveRecord::Base
  has_many :subscriptions
  has_many :subscription_payments
  
  COMMISSION = 0.20
  AFILIATE_SOWFTWARE = "ShareASale"
  
  validates_presence_of :token
  validates_uniqueness_of :token
  validates_numericality_of :rate, :greater_than_or_equal_to => 0,
    :less_than_or_equal_to => 1
    
  def self.merchant_id
    40631
  end
  
  def self.affiliate_param
    "SSAID"
  end
  
  def self.add_affiliate(account)
    if !account.conversion_metric.nil? and 
      account.conversion_metric.first_referrer.include?(affiliate_param)
      uri = account.conversion_metric.first_referrer
      env = Rack::MockRequest.env_for(uri)
      req = Rack::Request.new(env)
      params = req.params
      affiliate_id = params.fetch(affiliate_param)
      unless affiliate_id.nil?
        affiliate = find_by_token(affiliate_id)
        affiliate = create({:name => AFILIATE_SOWFTWARE,
                            :rate => COMMISSION,
                            :token => affiliate_id}) unless affiliate
       account.subscription.affiliate = affiliate  
       account.subscription.save
      end
    end
  end
  
  
  
  # Return the fees owed to an affiliate for a particular time
  # period. The period defaults to the previous month.
  def fees(period = (Time.now.beginning_of_month - 1).beginning_of_month .. (Time.now.beginning_of_month - 1).end_of_month)
    subscription_payments.all(:conditions => { :created_at => period }).collect(&:affiliate_amount).sum    
  end
end
