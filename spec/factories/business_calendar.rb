if ENV["RAILS_ENV"] == "test"
  Factory.define :business_calendars, :class =>BusinessCalendar do |bc|
    bc.name "Test hours"
    bc.description "Testing business hours"
    bc.business_time_data :working_hours =>
      { 1 => {:beginning_of_workday => "8:00 am", :end_of_workday => "5:00 pm"},
        2 => {:beginning_of_workday => "8:00 am", :end_of_workday => "5:00 pm"},
        3 => {:beginning_of_workday => "8:00 am", :end_of_workday => "5:00 pm"},
        4 => {:beginning_of_workday => "8:00 am", :end_of_workday => "5:00 pm"},
        5 => {:beginning_of_workday => "8:00 am", :end_of_workday => "5:00 pm"}},
      :weekdays => [1, 2, 3, 4, 5],
      :fullweek => false

    bc.holiday_data [["Jan 26","Republic Day"],["August 15","Independence Day"]]

  end
end
