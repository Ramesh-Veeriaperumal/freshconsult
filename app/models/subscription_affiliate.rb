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
    begin
    metrics = account.conversion_metric
    if !metrics.nil? and 
      (metrics.first_referrer.include?(affiliate_param) || 
       metrics.referrer.include?(affiliate_param))
      uri = metrics.referrer.include?(affiliate_param) ? metrics.referrer : metrics.first_referrer
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
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
      FreshdeskErrorsMailer.deliver_error_email(nil,nil,e,{:subject => "Error creating subscription affiliate"})
    end
  end
  
  
  
  # Return the fees owed to an affiliate for a particular time
  # period. The period defaults to the previous month.
  def fees(period = (Time.now.beginning_of_month - 1).beginning_of_month .. (Time.now.beginning_of_month - 1).end_of_month)
    subscription_payments.all(:conditions => { :created_at => period }).collect(&:affiliate_amount).sum    
  end
end
