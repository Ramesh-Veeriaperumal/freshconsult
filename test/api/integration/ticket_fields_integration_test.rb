require_relative '../test_helper'

class TicketFieldsIntegrationTest < ActionDispatch::IntegrationTest
  def test_query_count
    skip_bullet do
      v2 = {}
      v1 = {}
      v2_expected = {
        api_index: 4,

        index: 25
      }

      # index
      v2[:index], v2[:api_index], v2[:index_queries] = count_api_queries do
        get('/api/ticket_fields', nil, @headers)
        assert_response :success
      end
      v1[:index] = count_queries do
        get('/ticket_fields.json', nil, @headers)
        assert_response :success
      end

      write_to_file(v1, v2)

      v1.keys.each do |key|
        api_key = "api_#{key}".to_sym
        assert v2[key] <= v1[key]
        assert_equal v2_expected[api_key], v2[api_key]
        assert_equal v2_expected[key], v2[key]
      end
    end
  end
end
