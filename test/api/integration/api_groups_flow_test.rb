require_relative '../test_helper'

class ApiGroupsFlowTest < ActionDispatch::IntegrationTest
  include Helpers::GroupsTestHelper
  JSON_ROUTES = Rails.application.routes.routes.select do |r|
    r.path.spec.to_s.starts_with('/api/groups/') &&
    ['post', 'put'].include?(r.send(:verb).inspect.gsub(/[^0-9A-Za-z]/, '').downcase)
  end.collect do |x|
    [
      x.path.spec.to_s.gsub('(.:format)', ''),
      x.send(:verb).inspect.gsub(/[^0-9A-Za-z]/, '').downcase
    ]
  end.to_h

  JSON_ROUTES.each do |path, verb|
    define_method("test_#{path}_#{verb}_with_multipart") do
      headers, params = encode_multipart(v2_group_params)
      skip_bullet do
        send(verb.to_sym, path, params, @write_headers.merge(headers))
      end
      assert_response 415
      response.body.must_match_json_expression(un_supported_media_type_error_pattern)
    end
  end

  def test_empty_agent_ids
    skip_bullet do
      params = v2_group_params
      post '/api/groups', params.to_json, @write_headers
      assert_response 201
      group = Group.find_by_name(params[:name])
      assert group.agent_groups.count == 2

      put "/api/groups/#{group.id}", { agent_ids: nil }.to_json, @write_headers
      match_json([bad_request_error_pattern('agent_ids', 'data_type_mismatch', data_type: 'Array')])

      put "/api/groups/#{group.id}", { agent_ids: [] }.to_json, @write_headers
      assert_response 200
      assert group.reload.agent_groups.count == 0
    end
  end
end
