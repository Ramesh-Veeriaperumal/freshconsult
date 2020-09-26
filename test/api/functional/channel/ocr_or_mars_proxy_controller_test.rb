# frozen_string_literal: true

require_relative '../../test_helper'
require 'webmock/minitest'
WebMock.allow_net_connect!

module Channel
  class OcrOrMarsProxyControllerTest < ActionController::TestCase
    include ::OmniChannelRouting::Constants
    include Redis::OthersRedis
    include Redis::RedisKeys

    def test_next_eligible_agents_with_wrong_service
      @controller.env['PATH_INFO'] = 'api/v1/agents/next-eligible'
      @controller.request.env['Authorization'] = "Token #{generate_ocr_jwt('freshdesk')}"
      get 'execute', controller_params(version: 'channel')
      assert_response 403
    end

    def test_next_eligible_agents_with_invalid_token
      @controller.env['PATH_INFO'] = 'api/v1/agents/next-eligible'
      @controller.request.env['Authorization'] = "Token abcdefgh"
      stubbed_request = stub_request(:get, 'http://localhost:3001/api/v1/agents/next-eligible').to_return(body: {}.to_json, status: 401)
      get 'execute', controller_params(version: 'channel')
      assert_response 401
    ensure
      remove_request_stub(stubbed_request)
    end

    def test_next_eligible_agents_with_production_env
      @controller.env['PATH_INFO'] = 'api/v1/agents/next-eligible'
      @controller.request.env['Authorization'] = "Token #{generate_ocr_jwt('freshcaller')}"
      Rails.env.stubs(:production?).returns(true)
      get 'execute', controller_params(version: 'channel')
      assert_response 404
    ensure
      Rails.env.unstub(:production?)
    end

    def test_next_eligible_agents_with_agent_statuses_feature
      Account.current.launch(:agent_statuses)
      add_member_to_redis_set(AGENT_STATUSES_CALLER_ACCOUNT_IDS, Account.current.id)
      @controller.env['PATH_INFO'] = 'api/v1/agents/next-eligible'
      @controller.request.env['Authorization'] = "Token #{generate_ocr_jwt('freshcaller')}"
      stubbed_request = stub_request(:get, 'http://localhost:8080/api/v1/agents/next-eligible').to_return(body: {}.to_json, status: 200)
      get 'execute', controller_params(version: 'channel')
      assert_response 200
    ensure
      remove_request_stub(stubbed_request)
      Account.current.rollback(:agent_statuses)
      remove_member_from_redis_set(AGENT_STATUSES_CALLER_ACCOUNT_IDS, Account.current.id)
    end

    def test_next_eligible_agents_without_agent_statuses_feature
      @controller.env['PATH_INFO'] = 'api/v1/agents/next-eligible'
      @controller.request.env['Authorization'] = "Token #{generate_ocr_jwt('freshcaller')}"
      stubbed_request = stub_request(:get, 'http://localhost:3001/api/v1/agents/next-eligible').to_return(body: {}.to_json, status: 200)
      get 'execute', controller_params(version: 'channel')
      assert_response 200
    ensure
      remove_request_stub(stubbed_request)
    end

    def test_next_eligible_agents_with_exception
      @controller.env['PATH_INFO'] = 'api/v1/agents/next-eligible'
      @controller.request.env['Authorization'] = "Token #{generate_ocr_jwt('freshcaller')}"
      stubbed_request = stub_request(:get, 'http://localhost:3001/api/v1/agents/next-eligible').to_return(body: { 'code': 602, 'message': 'group_id in query is required' }.to_json, status: 422)
      get 'execute', controller_params(version: 'channel')
      assert_response 422
    ensure
      remove_request_stub(stubbed_request)
    end

    private

      def generate_ocr_jwt(client_service)
        JWT.encode(
          ocr_jwt_payload(client_service),
          OCR_CLIENT_SECRET_KEYS[:freshdesk],
          OCR_JWT_SIGNING_ALG,
          OCR_JWT_HEADER
        )
      end

      def ocr_jwt_payload(client_service)
        acc_id = Account.current.id
        {
          account_id: acc_id.to_s,
          service: client_service,
          actor: User.current.try(:id).to_s
        }
      end
    end
end
