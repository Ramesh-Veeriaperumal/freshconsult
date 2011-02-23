#Well, it is not a sexy name, but everything else is taken by business_time plugin.

class BusinessCalendar < ActiveRecord::Base
  serialize :business_time_data
  serialize :holidays
  
  #business_time_data has working days and working hours inside.
  #for now, a sporadically structured hash is used.
  #can revisit this data model later...
  
  belongs_to :account
  
  attr_accessible :holidays
  
  HOLIDAYS_JSON ='[{holidays: [Jan 01, Jan 26, Feb 14, Mar 31]}]'
  
  BUSINESS_TIME = '[{working_days :[Mon,Tues,Wed,Thu,Fri],
                    working_hours: [{full_time:true}, {[starting_time:9.30 am,end_time:6.30 pm] }] }]'
  
  
  DEFAULT_SEED_DATA = {
    :beginning_of_workday => '9:00 am',
    :end_of_workday => '6:00 pm',
    :weekdays => [1, 2, 3, 4, 5]
  }
  
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
