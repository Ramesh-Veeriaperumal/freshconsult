#Well, it is not a sexy name, but everything else is taken by business_time plugin.

class BusinessCalendar < ActiveRecord::Base
  serialize :business_time_data
  serialize :holiday_data
  
  #business_time_data has working days and working hours inside.
  #for now, a sporadically structured hash is used.
  #can revisit this data model later...
  
  belongs_to :account
  
  attr_accessible :holiday_data,:business_time_data
  
  HOLIDAYS_JSON ='[{holidays: [Jan 01, Jan 26, Feb 14, Mar 31]}]'
   
  DEFAULT_SEED_DATA = {
    :beginning_of_workday => '9:00 am',
    :end_of_workday => '6:00 pm',
    :weekdays => [1, 2, 3, 4, 5],
    :fullweek => false
  }
  
  
    
  def beginning_of_workday
    business_time_data[:beginning_of_workday]
  end
  
  def end_of_workday
    business_time_data[:end_of_workday]
  end
  
  def weekdays
    business_time_data[:weekdays]
  end
  
  def fullweek
    business_time_data[:fullweek]
  end
  
  def holidays    
    holiday_data.nil? ? [] : holiday_data.map {|hol| ("#{hol[0]}, #{Time.zone.now.year}").to_date}      
  end
  
  
  def self.config
    Account.current ? Account.current.business_calendar : BusinessTime::Config
  end
end
