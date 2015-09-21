require_relative '../test_helper'

class ApiBusinessCalendarsIntegrationTest < ActionDispatch::IntegrationTest
  include BusinessCalendarsHelper

  def test_query_count
    v2 = {}
    v2_expected = {
      api_show: 1,
      api_index: 1,

      show: 12,
      index: 12
    }

    business_calendar = create_business_calendar
    id = business_calendar.id
    # show
    v2[:show], v2[:api_show], v2[:show_queries] = count_api_queries do
      get("/api/v2/business_calendars/#{id}", nil, @headers)
      assert_response 200
    end

    # index
    v2[:index], v2[:api_index], v2[:index_queries] = count_api_queries do
      get('/api/v2/business_calendars', nil, @headers)
      assert_response 200
    end

    write_to_file(nil, v2)

    v2_expected.keys.each do |key|
      assert_equal v2_expected[key], v2[key]
    end
  end
end
