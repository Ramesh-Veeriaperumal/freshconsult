module BusinessCalendarsTestHelper
  def create_business_calendar(params = {})
    business_calendar = FactoryGirl.build(:business_calendars,
                                          name: params[:name] || "created by #{Faker::Name.name}",
                                          description: Faker::Lorem.sentence(2),
                                          account_id: @account.id,
                                          time_zone: params[:time_zone] || @account.time_zone,
                                          business_time_data: params[:business_time_data] || { working_hours: {
                                            1 => { beginning_of_workday: '8:00 am', end_of_workday: '5:00 pm' },
                                            2 => { beginning_of_workday: '8:00 am', end_of_workday: '5:00 pm' },
                                            3 => { beginning_of_workday: '8:00 am', end_of_workday: '5:00 pm' },
                                            4 => { beginning_of_workday: '8:00 am', end_of_workday: '5:00 pm' },
                                            5 => { beginning_of_workday: '8:00 am', end_of_workday: '5:00 pm' }
                                          },
                                                                                               weekdays: [1, 2, 3, 4, 5],
                                                                                               fullweek: false },
                                          holiday_data: [['Jan 26', 'Republic Day'], ['Jan 1', 'New Year']],
                                          is_default: params[:is_default] || 0)
    business_calendar.save(validate: false)
    business_calendar
  end
end
