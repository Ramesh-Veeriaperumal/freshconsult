module BusinessCalenderConstants
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

  WEEKDAY_HUMAN_LIST = [ "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday" ]

  IRIS_NOTIFICATION_TYPE = 'omni_sync_status'.freeze

  # if the below status is changed, then it needs to be changed in the iris configuration.
  OMNI_SYNC_STATUS = {
      inprogress: 'INPROGRESS',
      failed: 'FAILED',
      success: 'SUCCESS'
  }

  def self.weekday_human_list
    WEEKDAY_HUMAN_LIST.map { |i| I18n.t("helpdesk_reports.days.#{i}") }
  end

  RESOURCE_NAME = 'business_calendar'.freeze
end