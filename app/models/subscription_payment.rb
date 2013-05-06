class SubscriptionPayment < ActiveRecord::Base
  
  serialize :meta_info
  
  include HTTParty
  
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
end
