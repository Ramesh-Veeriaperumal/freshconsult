require_relative '../test_helper'

class ApiCompanyFieldsIntegrationTest < ActionDispatch::IntegrationTest
  def test_query_count
    v2 = {}
    v2_api_index_query_count = 1
    v2_index_query_count = 14
    # index
    v2[:index], v2[:api_index] = count_api_queries { get('/api/v2/company_fields.json', nil, @headers) }
    
    p v2

    assert_equal v2_api_index_query_count, v2[:api_index]
    assert_equal v2_index_query_count, v2[:index]
  end
end
