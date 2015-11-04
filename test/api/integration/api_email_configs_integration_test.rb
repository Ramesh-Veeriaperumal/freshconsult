require_relative '../test_helper'

class ApiEmailConfigsIntegrationTest < ActionDispatch::IntegrationTest
  include EmailConfigsHelper
  def test_query_count
    v2 = {}
    v2_expected = {
      api_show: 1,
      api_index: 1,

      show: 12,
      index: 12
    }

    email_config = create_email_config
    id = email_config.id
    # show
    v2[:show], v2[:api_show], v2[:show_queries] = count_api_queries do
      get("/api/v2/email_configs/#{id}", nil, @headers)
      assert_response 200
    end

    # index
    v2[:index], v2[:api_index], v2[:index_queries] = count_api_queries do
      get('/api/v2/email_configs', nil, @headers)
      assert_response 200
    end

    write_to_file(nil, v2)

    v2_expected.keys.in_groups(2).last.each do |key|
      api_key = "api_#{key}".to_sym
      assert_equal v2_expected[api_key], v2[api_key]
      assert_equal v2_expected[key], v2[key]
    end
  end
end
