class SubscriptionEvent < ActiveRecord::Base
  
  belongs_to :account
  has_one :subscription, :through => :account                     

  class << self

    include Subscription::Events::Constants

    def events_for_last_30_days
      count(:conditions => {:created_at => (30.days.ago..Time.now.end_of_day)}, 
            :group => "code")
    end

    def revenue_for_last_30_days
      sum(:cmrr, :group => "code", 
                 :conditions => {:created_at => (30.days.ago..Time.now.end_of_day)})
    end

    def list_accounts(month, year, code)
      find(:all, :include => [ :account, { :account => :subscription_payments } ],
                  :conditions => ['MONTH(created_at) = ? AND YEAR(created_at) = ? 
                                                      AND code = ?', month, year, code])
    end

    def monthly_revenue(month, year, code)
      sum(:cmrr, :conditions => ['MONTH(created_at) = ? AND 
                                  YEAR(created_at) = ? AND code = ?', month, year, code])
    end

    def overall_monthly_revenue(month, year, code_range)
      sum(:cmrr, :conditions => ['MONTH(created_at) = ? AND 
                                  YEAR(created_at) = ? AND code IN (?)', month, year, code_range]) 
    end

    #Adding Event to db
    def add_event(account, attributes)
      return create_new_record(account, attributes) if (record = account.subscription_events).blank?

      update_record?(record) ? record.first.update_attributes(attributes) : 
                                        create_new_record(account, attributes)
    end
   
    def update_record?(record)      
      record.size.eql?(1) and (record.first.created_at > 30.days.ago) and 
                        record.first.code.eql?(CODES[:free])
    end   

    def create_new_record(account, attributes)
      account.subscription_events.create(attributes)
    end 
    
  end
end