require_relative '../test_helper'

class ApiContactFieldsIntegrationTest < ActionDispatch::IntegrationTest
  def test_query_count
    skip_bullet do
      v2 = {}
      v1 = {}
      v2_expected = {
        api_contact_fields: 1,

        contact_fields: 14
      }

      # contact_fields
      v2[:contact_fields], v2[:api_contact_fields] = count_api_queries { get('/api/v2/contact_fields', {}.to_json, @write_headers) }
      v1[:contact_fields] = count_queries { get('/admin/contact_fields.json', {}.to_json, @write_headers) }

      v1.keys.each do |key|
        api_key = "api_#{key}".to_sym
        Rails.logger.debug "key : #{api_key}, v1: #{v1[key]}, v2 : #{v2[key]}, v2_api: #{v2[api_key]}, v2_expected: #{v2_expected[key]}"
      end

      p v1
      p v2

      v1.keys.each do |key|
        api_key = "api_#{key}".to_sym
        Rails.logger.debug "key : #{api_key}, v1: #{v1[key]}, v2 : #{v2[key]}, v2_api: #{v2[api_key]}, v2_expected: #{v2_expected[key]}"
        assert v2[key] <= v1[key]
        assert_equal v2_expected[api_key], v2[api_key]
        assert_equal v2_expected[key], v2[key]
      end
    end
  end
end
