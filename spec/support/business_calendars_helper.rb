module BusinessCalendarsHelper
  def create_business_calendar
    business_calendar = FactoryGirl.build(:business_calendars, name: "created by #{Faker::Name.name}", description: Faker::Lorem.sentence(2), account_id: @account.id)
    business_calendar.save(validate: false)
    business_calendar
  end
end
