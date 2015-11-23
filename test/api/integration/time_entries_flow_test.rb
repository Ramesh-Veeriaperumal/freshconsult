require_relative '../test_helper'

class TimeEntriesFlowTest < ActionDispatch::IntegrationTest
  include Helpers::TimeEntriesTestHelper
  JSON_ROUTES = Rails.application.routes.routes.select do |r|
    r.path.spec.to_s.include?('time_entries') &&
    ['post', 'put'].include?(r.send(:verb).inspect.gsub(/[^0-9A-Za-z]/, '').downcase)
  end.collect do |x|
    [
      x.path.spec.to_s.gsub('(.:format)', ''),
      x.send(:verb).inspect.gsub(/[^0-9A-Za-z]/, '').downcase
    ]
  end.to_h

  JSON_ROUTES.each do |path, verb|
    define_method("test_#{path}_#{verb}_with_multipart") do
      headers, params = encode_multipart(v2_time_entry_params)
      skip_bullet do
        send(verb.to_sym, path, params, @write_headers.merge(headers))
      end
      assert_response 415
      response.body.must_match_json_expression(un_supported_media_type_error_pattern)
    end
  end

  def test_querying_with_time_zone
    zone = Time.zone
    Time.zone = 'UTC'
    utc_time = Time.zone.now
    utc_time_string = utc_time.iso8601
    zone_time = utc_time.in_time_zone('Chennai')
    zone_time_string = zone_time.iso8601
    group = Group.first || create_group(@account)
    group.update_column(:created_at, utc_time + 1.second)
    result = Group.where('created_at > ?', utc_time_string)
    assert_equal [group], result
    result = Group.where('created_at > ?', zone_time_string)
    assert_equal [], result # AR does not do time conversions to UTC when using string
    result = Group.where('created_at > ?', zone_time_string.to_time.utc) # Hence string have to be converted to UTC
    assert_equal [group], result
    result = Group.where('created_at > ?', DateTime.parse(zone_time_string)) # Or date_strings should be parsed to a Time object before using it for querying.
    assert_equal [group], result
    Time.zone = zone
  end
end
