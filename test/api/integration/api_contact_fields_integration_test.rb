require_relative '../test_helper'

class ApiContactFieldsIntegrationTest < ActionDispatch::IntegrationTest
  def test_query_count
    skip_bullet do
      v2 = {}
      v1 = {}
      v2_expected = {
        api_contact_fields: 1,

        contact_fields: 15
      }

      # contact_fields
      v2[:contact_fields], v2[:api_contact_fields], v2[:contact_fields_queries] = count_api_queries do
        get('/api/v2/contact_fields', nil, @write_headers)
        assert_response 200
      end
      v1[:contact_fields] = count_queries do
        get('/admin/contact_fields.json', nil, @write_headers)
        assert_response 200
      end

      v1[:contact_fields] += 2 # account suspended check is done in v2 alone& trusted_ip

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
