class SubscriptionPayment < ActiveRecord::Base
  
  serialize :meta_info
  
  include HTTParty

  NON_RECURRING_PAYMENTS = {
    :day_pass => "Day Pass",
    :freshfone => "Freshfone Credits"
  }
  
  belongs_to :subscription
  belongs_to :account
  belongs_to :affiliate, :class_name => 'SubscriptionAffiliate', :foreign_key => 'subscription_affiliate_id'
  
  def self.stats
    {
      :last_month => calculate(:sum, :amount, :conditions => { :created_at => ((Time.zone.now.ago 1.month).beginning_of_month .. (Time.zone.now.ago 1.month).end_of_month) }),
      :this_month => calculate(:sum, :amount, :conditions => { :created_at => (Time.zone.now.beginning_of_month .. Time.zone.now.end_of_month) }),
      :last_30 => calculate(:sum, :amount, :conditions => { :created_at => ((Time.zone.now.ago 1.month) .. Time.zone.now) })
    }
  end

  def self.day_pass_stats
    {
      :this_month => calculate(:sum, 
                               :amount, 
                               :joins => "INNER JOIN  day_pass_purchases on day_pass_purchases.payment_id = subscription_payments.id",
                               :conditions => { :created_at => (Time.zone.now.beginning_of_month .. Time.zone.now.end_of_month) })
    }
  end

  def agents
    meta_info[:agents]
  end

  def free_agents
    meta_info[:free_agents]
  end

  def plan_name
    plan_id = meta_info[:plan] 
    SubscriptionPlan.find(plan_id).name
  end

  def renewal_period
    meta_info[:renewal_period]
  end

  def renewal_type
    SubscriptionPlan::BILLING_CYCLE_NAMES_BY_KEY[subscription.renewal_period] 
  end

  def to_s
    return meta_info[:description] if misc
    name = "Freshdesk #{plan_name} #{renewal_type} subscription for #{agents} Agents 
           (with #{free_agents} free agent(s))"          
  end

  def usd_equivalent
    subscription.usd_equivalent
  end

  #One time payments
  def self.day_pass_purchases
    day_passes = 0
    non_recurring_payments.each do |payment|
      day_passes += payment.amount if payment.to_s.include?(NON_RECURRING_PAYMENTS[:day_pass])
    end
    day_passes
  end

  def self.freshfone_credits
    fone_credits = 0
    non_recurring_payments.each do |payment|
      fone_credits += payment.amount if payment.to_s.include?(NON_RECURRING_PAYMENTS[:freshfone])
    end
    fone_credits
  end

  def self.non_recurring_payments(start_date = 1.month.ago.beginning_of_month, 
      end_date = 1.month.ago.end_of_month.end_of_day)
    find(:all, 
      :joins => ["INNER JOIN subscriptions ON subscription_payments.account_id = 
                  subscriptions.account_id and subscriptions.state = 'active'"], 
      :conditions => [ "subscription_payments.created_at > ? AND subscription_payments.created_at < ? 
                        AND subscription_payments.misc = 1", start_date, end_date ])
  end

end
