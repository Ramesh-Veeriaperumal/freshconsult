class SubscriptionEvent < ActiveRecord::Base
  self.primary_key = :id
  
  belongs_to :account
  has_one :subscription, :through => :account                     

  class << self

    include Subscription::Events::Constants

    def events(start_date = Time.now.beginning_of_month, end_date = Time.now.end_of_day)
      {
        list: where(created_at: (start_date..end_date)).includes(:account).to_a,
        revenue: calculate(:sum, :cmrr, group: 'code', conditions: { created_at: (start_date..end_date) })
      }
    end

    def upgrades(start_date = Time.now.beginning_of_month, end_date = Time.now.end_of_day)
      {
        list: where(created_at: (start_date..end_date), code: (METRICS[:upgrades])).to_a,
        revenue: calculate(:sum, :cmrr, condition: { created_at: (start_date..end_date), code: (METRICS[:upgrades]) })
      }
    end

    def downgrades(start_date = Time.now.beginning_of_month, end_date = Time.now.end_of_day)
      {
        list: where(created_at: (start_date..end_date), code: (METRICS[:downgrades])).to_a,
        revenue: calculate(:sum, :cmrr, conditions: { created_at: (start_date..end_date), code: (METRICS[:downgrades]) })
      }
    end

    def cmrr_last_30_days
      where(created_at: (Time.now.beginning_of_month..Time.now.end_of_day), code: (METRICS[:cmrr])).sum(:cmrr)
    end

    def cmrr(start_date, end_date)
      where(created_at: (start_date..end_date), code: (METRICS[:cmrr])).sum(:cmrr)
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
    
    def deleted_event(account_id)
      find_by_account_id_and_code(account_id, CODES[:deleted])
    end
    
  end
end