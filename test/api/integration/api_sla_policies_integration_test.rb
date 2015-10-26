require_relative '../test_helper'

class ApiSlaPoliciesIntegrationTest < ActionDispatch::IntegrationTest
  include Helpers::SlaPoliciesHelper

  JSON_ROUTES = Rails.application.routes.routes.select do |r|
    r.path.spec.to_s.starts_with('/api/sla_policies/') &&
    ['post', 'put'].include?(r.send(:verb).inspect.gsub(/[^0-9A-Za-z]/, '').downcase)
  end.collect do |x|
    [
      x.path.spec.to_s.gsub('(.:format)', ''),
      x.send(:verb).inspect.gsub(/[^0-9A-Za-z]/, '').downcase
    ]
  end.to_h

  JSON_ROUTES.each do |path, verb|
    define_method("test_#{path}_#{verb}_with_multipart") do
      headers, params = encode_multipart(sla_policy_params)
      skip_bullet do
        send(verb.to_sym, path, params, @write_headers.merge(headers))
      end
      assert_response 415
      response.body.must_match_json_expression(un_supported_media_type_error_pattern)
    end
  end

  def test_query_count
    skip_bullet do
      v2 = {}
      v1 = {}
      v2_expected = {
        api_update: 7,
        api_index: 1,

        update: 18,
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
      v2[:index], v2[:api_index], v2[:index_queries] = count_api_queries do
        get('/api/v2/sla_policies', nil, @headers)
        assert_response 200
      end

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
