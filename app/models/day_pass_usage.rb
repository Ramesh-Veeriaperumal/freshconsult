class DayPassUsage < ActiveRecord::Base
  serialize :usage_info, Hash
  
  belongs_to :account
  belongs_to :user
  
  named_scope :on_the_day, lambda { |start_time| 
    { :conditions => { :granted_on => start_time } }}
  
  def self.start_time
    Time.zone.now.beginning_of_day
  end
end
