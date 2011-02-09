#Well, it is not a sexy name, but everything else is taken by business_time plugin.

class BusinessCalendar < ActiveRecord::Base
  serialize :business_time_data
  serialize :holidays
  
  #business_time_data has working days and working hours inside.
  #for now, a sporadically structured hash is used.
  #can revisit this data model later...
  
  belongs_to :account
  
  attr_accessible :holidays
  
  def after_find
    self.holidays ||= []
  end
    
  def beginning_of_workday
    business_time_data[:beginning_of_workday]
  end
  
  def end_of_workday
    business_time_data[:end_of_workday]
  end
  
  def weekdays
    business_time_data[:weekdays]
  end
  
  def self.config
    Account.current ? Account.current.business_calendar : BusinessTime::Config
  end
end
