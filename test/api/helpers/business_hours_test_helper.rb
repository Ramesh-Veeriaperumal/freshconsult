require "#{Rails.root}/spec/support/business_calendars_helper.rb"
module BusinessHoursTestHelper
  include BusinessCalendarsHelper
  # Patterns
  def business_hour_pattern(expected_output = {}, business_hour)
    bc_json = business_hour_default_pattern(expected_output, business_hour)
    bc_json[:time_zone] = business_hour.time_zone
    bc_json[:is_default] = business_hour.is_default.to_s.to_bool
    bc_json
  end

  def business_hour_index_pattern(expected_output = {}, business_hour)
    bc_json = business_hour_default_pattern(expected_output, business_hour, true)
    bc_json
  end

  def business_hour_default_pattern(expected_output, business_hour, index_request = false)
    expected_output[:ignore_created_at] ||= true
    expected_output[:ignore_updated_at] ||= true
    result = {
      id: Fixnum,
      name: expected_output[:name] || business_hour.name,
      description: business_hour.description,
      business_hours: business_hour.business_intervals,
      time_zone: business_hour.time_zone,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
    result[:holiday_list] = business_hour.holiday_data unless index_request
    result
  end

  def ember_business_hour_index_pattern(business_hour)
    result = {
      id: Integer,
      name: business_hour.name,
      description: business_hour.description,
      time_zone: business_hour.time_zone,
      default: business_hour.is_default,
      group_ids: Account.current.groups_from_cache.select { |group| group.business_calendar_id == business_hour.id }.map(&:id)
    }
    result
  end

  def ember_business_hour_show_pattern(business_hour)
    {
      id: business_hour.id,
      name: business_hour.name,
      description: business_hour.description,
      time_zone: business_hour.time_zone,
      default: business_hour.is_default,
      holidays: business_hour.holiday_data.map { |data| { name: data[1], date: data[0] } },
      channel_business_hours: business_hour.channel_bussiness_hour_data
    }
  end
end
