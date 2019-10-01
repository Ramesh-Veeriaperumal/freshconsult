module BusinessCalendarsHelper
  def create_business_calendar
    business_calendar = FactoryGirl.build(:business_calendars, name: "created by #{Faker::Name.name}", description: Faker::Lorem.sentence(2), account_id: @account.id, holiday_data: [['Jan 26', 'Republic Day'], ['Jan 1', 'New Year']])
    business_calendar.save(validate: false)
    business_calendar
  end
end
