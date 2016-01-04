require_relative '../test_helper'

class ApiBusinessHoursIntegrationTest < ActionDispatch::IntegrationTest
  include BusinessCalendarsHelper

  def test_query_count
    v2 = {}
    v2_expected = {
      api_show: 1,
      api_index: 1,

      show: 15,
      index: 14
    }

    business_hour = create_business_calendar
    id = business_hour.id
    # show
    v2[:show], v2[:api_show], v2[:show_queries] = count_api_queries do
      get("/api/v2/business_hours/#{id}", nil, @headers)
      assert_response 200
    end

    # index
    v2[:index], v2[:api_index], v2[:index_queries] = count_api_queries do
      get('/api/v2/business_hours', nil, @headers)
      assert_response 200
    end

    write_to_file(nil, v2)

    v2_expected.keys.each do |key|
      assert_equal v2_expected[key], v2[key]
    end
  end
end
