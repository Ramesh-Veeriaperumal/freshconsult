require_relative '../../test_helper'

class ApiSlaPoliciesQueriesTest < ActionDispatch::IntegrationTest
  include SlaPoliciesTestHelper

  def test_query_count
    skip_bullet do
      v2 = {}
      v1 = {}
      v2_expected = {
        api_update: 8,
        api_index: 2,

        update: 17,
        index: 11
      }
      agent = add_test_agent(@account)
      sp1 = create_sla_policy(agent)
      sp2 = create_sla_policy(agent)
      v2_payload = v2_sla_policy_payload
      v1_payload = v1_sla_policy_payload

      # update
      v1[:update] = count_queries do
        put("/helpdesk/sla_policies/#{sp2.id}/company_sla.json", v1_payload, @write_headers)
        assert_response 200
      end
      v2[:update], v2[:api_update], v2[:update_queries] = count_api_queries do
        put("/api/v2/sla_policies/#{sp1.id}", v2_payload, @write_headers)
        assert_response 200
      end
      # index
      v1[:index] = count_queries do
        get('/helpdesk/sla_policies.json', nil, @headers)
        assert_response 200
      end

      v1[:index] += 1 # account not suspended check is done only in version2.

      v2[:index], v2[:api_index], v2[:index_queries] = count_api_queries do
        get('/api/v2/sla_policies', nil, @headers)
        assert_response 200
      end

      v1[:index] += 1 # trusted_ip

      write_to_file(v1, v2)

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
