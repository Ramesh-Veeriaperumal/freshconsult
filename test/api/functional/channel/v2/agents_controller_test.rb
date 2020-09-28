require_relative '../../../test_helper'

module Channel::V2
  class AgentsControllerTest < ActionController::TestCase
    include UsersTestHelper
    include AgentsTestHelper
    include JwtTestHelper
    include CentralLib::CentralResyncHelper
    include CentralLib::CentralResyncConstants
    include Redis::OthersRedis

    SOURCE = 'analytics'.freeze

    def wrap_cname(params)
      params
    end

    def setup
      super
      Account.stubs(:current).returns(Account.first)
      User.stubs(:current).returns(User.first)
    end

    def teardown
      super
    end

    def test_verify_agent_privilege
      set_jwt_auth_header('freshdesk')
      get :verify_agent_privilege, controller_params(version: 'private')
      pattern = { admin: User.current.roles.map(&:name).include?('Account Administrator' || 'Administrator'),
                  allow_agent_to_change_status: User.current.toggle_availability?,
                  supervisor: User.current.privilege?(:manage_availability) }
      match_json(pattern)
      assert_response 200
    end

    def test_agents_resync_with_invalid_meta
      set_jwt_auth_header(SOURCE)
      remove_others_redis_key(resync_rate_limiter_key(SOURCE))
      args = { meta: nil }
      post :sync, construct_params({ version: 'channel' }, args)
      assert_response 400
      pattern = validation_error_pattern(bad_request_error_pattern(:meta, "can't be blank", code: 'invalid_value'))
      match_json(pattern)
    end

    def test_agents_resync_success
      set_jwt_auth_header(SOURCE)
      job_id = SecureRandom.hex
      request.stubs(:uuid).returns(job_id)
      remove_others_redis_key(resync_rate_limiter_key(SOURCE))
      expected_body = { 'job_id' => job_id }
      args = { meta: { meta_id: 'abc' } }
      post :sync, construct_params({ version: 'channel' }, args)
      response_body = parse_response @response.body
      assert_response 202
      assert_equal expected_body, response_body
    ensure
      request.unstub(:uuid)
    end

    def test_agents_resync_with_auth_failure
      remove_others_redis_key(resync_rate_limiter_key(SOURCE))
      args = { meta: { meta_id: 'abc' } }
      post :sync, construct_params({ version: 'channel' }, args)
      assert_response 401
    end

    private

      def error_response(error)
        { 'errors' => [error] }
      end
  end
end
