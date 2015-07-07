require_relative '../test_helper'

class ApiEmailConfigsIntegrationTest < ActionDispatch::IntegrationTest
  def test_query_count
    v2 = {}
    v2_expected = {
      show: 2,
      index: 1
    }

    email_config = create_email_config
    id = email_config.id
    # show
    v2[:show], v2[:api_show] = count_api_queries { get("/api/v2/groups/#{id}", nil, @headers) }

    # index
    v2[:index], v2[:api_index] = count_api_queries { get('/api/v2/groups', nil, @headers) }

    v2.keys.each do |key|
      api_key = "api_#{key}".to_sym
      assert_equal v2_expected[key], v2[api_key]
    end
  end
end
