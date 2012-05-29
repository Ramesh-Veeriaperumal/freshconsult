class SubscriptionPayment < ActiveRecord::Base
  
  include HTTParty
  
  belongs_to :subscription
  belongs_to :account
  belongs_to :affiliate, :class_name => 'SubscriptionAffiliate', :foreign_key => 'subscription_affiliate_id'
  
  before_create :set_info_from_subscription
  before_create :calculate_affiliate_amount
  after_create :send_receipt
  after_create :update_affiliate, :if => :affiliate
  
  def self.stats
    {
      :last_month => calculate(:sum, :amount, :conditions => { :created_at => (1.month.ago.beginning_of_month .. 1.month.ago.end_of_month) }),
      :this_month => calculate(:sum, :amount, :conditions => { :created_at => (Time.zone.now.beginning_of_month .. Time.zone.now.end_of_month) }),
      :last_30 => calculate(:sum, :amount, :conditions => { :created_at => (1.month.ago .. Time.zone.now) })
    }
  end
  
  protected
  
    def set_info_from_subscription
      self.account = subscription.account
      self.affiliate = subscription.affiliate
    end

    def calculate_affiliate_amount
      return unless affiliate
      self.affiliate_amount = amount * affiliate.rate
    end
    
    def send_receipt
      return unless amount > 0
      if setup?
        SubscriptionNotifier.deliver_setup_receipt(self)
      elsif misc?
        #SubscriptionNotifier.deliver_misc_receipt(self) #Has been moved to subscription itself.
      else
        SubscriptionNotifier.deliver_charge_receipt(self)
      end
      true
  end
  
   def update_affiliate
    send_later(:make_api_call)
  end
 
 def make_api_call
    begin
     if subscription.subscription_payments.first.created_at > 1.year.ago
      response = HTTParty.get('https://shareasale.com/q.cfm',:query => {:amount => amount,
                                         :tracking => id,
                                         :transtype => "sale",
                                         :merchantID => SubscriptionAffiliate.merchant_id,
                                         :userID => affiliate.token})
     end

   rescue Exception => e
      NewRelic::Agent.notice_error(e)
      FreshdeskErrorsMailer.deliver_error_email(nil,nil,e,{:subject => "Error contacting shareAsale #{id}"})
     end
 end
  
end
