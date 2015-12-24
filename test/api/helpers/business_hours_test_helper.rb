module Helpers::BusinessHoursTestHelper
  include BusinessCalendarsHelper
  # Patterns
  def business_hour_pattern(expected_output = {}, business_hour)
    bc_json = business_hour_default_pattern(expected_output, business_hour)
    bc_json[:time_zone] = business_hour.time_zone
    bc_json[:is_default] = business_hour.is_default.to_s.to_bool
    bc_json
  end

  def business_hour_index_pattern(expected_output = {}, business_hour)
    bc_json = business_hour_default_pattern(expected_output, business_hour)
    bc_json
  end

  def business_hour_default_pattern(expected_output, business_hour)
    expected_output[:ignore_created_at] ||= true
    expected_output[:ignore_updated_at] ||= true
    {
      id: Fixnum,
      name: expected_output[:name] || business_hour.name,
      description: business_hour.description,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end
end
