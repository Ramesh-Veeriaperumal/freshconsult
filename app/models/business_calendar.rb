#Well, it is not a sexy name, but everything else is taken by business_time plugin.

class BusinessCalendar < ActiveRecord::Base
  serialize :business_time_data
  serialize :holiday_data
  
  #business_time_data has working days and working hours inside.
  #for now, a sporadically structured hash is used.
  #can revisit this data model later...
end
