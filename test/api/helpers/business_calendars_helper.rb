module Helpers::BusinessCalendarsHelper
  include BusinessCalendarsHelper
  # Patterns
  def business_calendar_pattern(expected_output = {}, business_calendar)
    bc_json = businesss_calendar_default_pattern(expected_output, business_calendar)
    bc_json[:time_zone] = business_calendar.time_zone
    bc_json[:is_default] = business_calendar.is_default.to_s.to_bool
    bc_json
  end

  def business_calendar_index_pattern(expected_output = {}, business_calendar)
    bc_json = businesss_calendar_default_pattern(expected_output, business_calendar)
    bc_json
  end

  def businesss_calendar_default_pattern(expected_output, business_calendar)
    expected_output[:ignore_created_at] ||= true
    expected_output[:ignore_updated_at] ||= true
    {
      id: Fixnum,
      name: expected_output[:name] || business_calendar.name,
      description: business_calendar.description,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end
end
