require_relative '../test_helper'

class TicketFieldsIntegrationTest < ActionDispatch::IntegrationTest
  def test_query_count
    v2 = {}
    v1 = {}
    v2_expected = {
      index: 7
    }

    # index
    v2[:index], v2[:api_index] = count_api_queries { get('/api/ticket_fields', nil, @headers) }
    v1[:index] = count_queries { get('/ticket_fields.json', nil, @headers) }

    v1.keys.each do |key|
      api_key = "api_#{key}".to_sym
      assert v2[key] <= v1[key]
      assert_equal v2_expected[key], v2[api_key]
    end
  end
end
