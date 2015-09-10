require_relative '../test_helper'

class ApiCompanyFieldsIntegrationTest < ActionDispatch::IntegrationTest
  def test_query_count
    v2 = {}
    v2_api_index_query_count = 1
    v2_index_query_count = 13
    # index
    v2[:index], v2[:api_index], v2[:index_queries] = count_api_queries do
      get('/api/v2/company_fields.json', nil, @headers)
      assert_response :success
    end

    write_to_file(nil, v2)

    assert_equal v2_api_index_query_count, v2[:api_index]
    assert_equal v2_index_query_count, v2[:index]
  end
end
