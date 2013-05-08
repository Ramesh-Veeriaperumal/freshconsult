# encoding: utf-8
#Well, it is not a sexy name, but everything else is taken by business_time plugin.

class BusinessCalendar < ActiveRecord::Base
  serialize :business_time_data
  serialize :holiday_data
  
  #business_time_data has working days and working hours inside.
  #for now, a sporadically structured hash is used.
  #can revisit this data model later...
  belongs_to :account
  before_create :set_default_version 
  attr_accessible :holiday_data,:business_time_data,:version
  validate_on_update :valid_working_hours?

  #needed for upgrading business_time_data - Abhinav
  BUSINESS_TIME_INFO = [:fullweek, :weekdays] 
  WORKING_HOURS_INFO = [:beginning_of_workday, :end_of_workday]
  #migration code ends

  TIME_LIST =[  "1:00" , "1:30" , "2:00" , "2:30" , "3:00" , 
                "3:30" , "4:00" , "4:30" , "5:00" , "5:30" ,
                "6:00" , "6:30" , "7:00" , "7:30" , "8:00" , 
                "8:30" , "9:00" , "9:30" , "10:00" , "10:30" , 
                "11:00" ,"11:30" ,"12:00", "12:30" 
              ]
  
  HOLIDAYS_SEED_DATA =[ ["Jan 16", "Birthday of Martin Luther King Jr"], 
                        ["Feb 20", "Washington’s Birthday"], 
                        ["May 28", "Memorial Day"],
                        ["Jul 04", "Independence Day"],
                        ["Sep 03", "Labor Day"],
                        ["Oct 08", "Columbus Day"],
                        ["Nov 11", "Veterans Day"],
                        ["Nov 22", "Thanksgiving Day"],
                        ["Dec 25", "Christmas Day"],
                        ["Jan 01", "New Year’s Day"]  ]
   
  DEFAULT_SEED_DATA = {
    :working_hours => { 1 => {:beginning_of_workday => "8:00 am", :end_of_workday => "5:00 pm"},
                        2 => {:beginning_of_workday => "8:00 am", :end_of_workday => "5:00 pm"},
                        3 => {:beginning_of_workday => "8:00 am", :end_of_workday => "5:00 pm"},
                        4 => {:beginning_of_workday => "8:00 am", :end_of_workday => "5:00 pm"},
                        5 => {:beginning_of_workday => "8:00 am", :end_of_workday => "5:00 pm"}
                      },
    :weekdays => [1, 2, 3, 4, 5],
    :fullweek => false
  }  
  def beginning_of_workday day
    business_time_data[:working_hours][day][:beginning_of_workday]
  end
  
  def end_of_workday day
    business_time_data[:working_hours][day][:end_of_workday]
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

  def working_hours 
    business_time_data[:working_hours]
  end
  
  def self.config
    Account.current ? Account.current.business_calendar : BusinessTime::Config
  end

  #migration code starts here..
  def upgraded_business_time_data
    business_data = self.business_time_data
    business_time = BUSINESS_TIME_INFO.inject({}) {|h,v| h[v] = business_data[v]; h}
    business_time[:working_hours] = Hash.new
    business_time[:weekdays].each do |n|
      business_time[:working_hours][n] = WORKING_HOURS_INFO.inject({}) {|h,v| h[v] = business_data[v]; h}
    end
    self.version = 2
    return business_time
  end

  def after_find
    if (version == 1) 
      self.business_time_data = upgraded_business_time_data 
      self.save
    end
  end
  #migrtation code ends..

  private 

    def valid_working_hours?
      if (version != 1)
        weekdays.each do |n|
          errors.add_to_base("Enter a valid Time") if (Time.zone.parse(beginning_of_workday(n))  >
             Time.zone.parse(end_of_workday(n)))
        end
      end
    end

    def set_default_version
      self.version = 2
    end

end
