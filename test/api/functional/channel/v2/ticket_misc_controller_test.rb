require_relative '../../../test_helper'
require 'webmock/minitest'

module Channel::V2
  class TicketMiscControllerTest < ActionController::TestCase
    include ApiTicketsTestHelper
    include QueryHashHelper

    def setup
      super
    end

    def match_filter_response_with_es_enabled(ticket_filter)
      enable_es_api_load(ticket_filter) do
        response_stub = filter_factory_filter_es_response_stub(ticket_filter.data)
        SearchService::Client.any_instance.stubs(:query).returns(SearchService::Response.new(response_stub))
        SearchService::Response.any_instance.stubs(:records).returns(JSON.parse(response_stub))
        get :index, controller_params(version: 'private', filter_id: ticket_filter.id)
        assert_response 200
        match_json(private_api_ticket_index_filter_pattern(ticket_filter.data))
      end
    end

    def enable_es_api_load(_params)
      Account.any_instance.stubs(:new_es_api_enabled?).returns(true)
      yield if block_given?
    ensure
      Account.any_instance.unstub(:new_es_api_enabled?)
    end

    def test_index_with_default_filter_id
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      ticket_filter = @account.ticket_filters.find_by_name('Urgent and High priority Tickets')
      get :index, controller_params(filter_id: ticket_filter.id)
      assert_response 200
    ensure
      @channel_v2_api = false
      CustomRequestStore.store[:channel_api_request] = false
    end

    def test_index_with_custom_filter_id
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      custom_filter = create_filter
      get :index, controller_params(filter_id: custom_filter.id)
      assert_response 200
      match_json(private_api_ticket_index_filter_pattern(custom_filter.data))
      match_filter_response_with_es_enabled(custom_filter)
    ensure
      @channel_v2_api = false
      CustomRequestStore.store[:channel_api_request] = false
    end

    def test_index_with_custom_filter_id_with_permission_check
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      user = add_test_agent(@account, role: Role.find_by_name('Agent').id)
      filter_params = {
        custom_ticket_filter: {
          visibility: {
            visibility: Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me],
            user_id: user.id
          }
        }
      }
      custom_filter = create_filter(nil, filter_params)
      get :index, controller_params(filter_id: custom_filter.id)
      assert_response 400
    ensure
      @channel_v2_api = false
      CustomRequestStore.store[:channel_api_request] = false
    end
  end
end
