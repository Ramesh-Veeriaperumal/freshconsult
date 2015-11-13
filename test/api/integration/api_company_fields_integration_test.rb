require_relative '../test_helper'

class ApiCompanyFieldsIntegrationTest < ActionDispatch::IntegrationTest
  def test_query_count
    skip_bullet do
      v2 = {}
      v1 = {}
      v2_api_index_query_count = 1
      v2_index_query_count = 14
      # index
      v2[:index], v2[:api_index], v2[:index_queries] = count_api_queries do
        get('/api/v2/company_fields.json', nil, @headers)
        assert_response 200
      end

      v1[:index] = count_queries do
        get('/admin/company_fields.json', nil, @headers)
        assert_response 200
      end

      write_to_file(v1, v2)

      assert v2[:index] <= v1[:index]
      assert_equal v2_api_index_query_count, v2[:api_index]
      assert_equal v2_index_query_count, v2[:index]
    end
  end
end
