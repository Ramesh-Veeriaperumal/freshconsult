class SubscriptionEvent < ActiveRecord::Base
  
  belongs_to :account
  has_one :subscription, :through => :account                     

  class << self

    include Subscription::Events::Constants

    def events(start_date = Time.now.beginning_of_month, end_date = Time.now.end_of_day)
      {
        :list => find(:all, :include => :account, 
                      :conditions => { :created_at => (start_date..end_date) } ), 
        
        :revenue => calculate(:sum, :cmrr, 
                              :group => "code",
                              :conditions => {:created_at => (start_date..end_date)})
      }
    end

    def upgrades(start_date = Time.now.beginning_of_month, end_date = Time.now.end_of_day)
      {
        :list => find(:all, :conditions => { :created_at => (start_date..end_date),
                                              :code => (METRICS[:upgrades]) }), 
        
        :revenue => calculate(:sum, :cmrr, :conditions => { :created_at => (start_date..end_date),
                                                            :code => (METRICS[:upgrades]) }), 
      }
    end

    def downgrades(start_date = Time.now.beginning_of_month, end_date = Time.now.end_of_day)
      {
        :list => find(:all, :conditions => { :created_at => (start_date..end_date),
                                              :code => (METRICS[:downgrades]) }), 
        
        :revenue => calculate(:sum, :cmrr, :conditions => { :created_at => (start_date..end_date),
                                                            :code => (METRICS[:downgrades]) }), 
      }
    end

    def cmrr_last_30_days
      sum(:cmrr, :conditions => { :created_at => (Time.now.beginning_of_month..Time.now.end_of_day),
                                  :code => (METRICS[:cmrr]) })
    end

    def cmrr(start_date, end_date)
      sum(:cmrr, :conditions => { :created_at => (start_date..end_date),
                                  :code => (METRICS[:cmrr]) })
    end

    def actual_revenue(start_date = Time.now.beginning_of_month, end_date = Time.now.end_of_day)
      sum(:cmrr, :conditions => { :created_at => (start_date..end_date) })
    end

    #Adding Event to db
    def add_event(account, attributes)
      return create_new_record(account, attributes) if (record = account.subscription_events).blank?

      update_record?(record) ? record.first.update_attributes(attributes) : 
                                        create_new_record(account, attributes)
    end
   
    def update_record?(record)      
      record.size.eql?(1) and (record.first.created_at.month == Time.now.month) and 
        (record.first.created_at.year == Time.now.year) and record.first.code.eql?(CODES[:free])
    end   

    def create_new_record(account, attributes)
      account.subscription_events.create(attributes)
    end 
    
  end
end