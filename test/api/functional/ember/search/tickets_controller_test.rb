require_relative '../../../test_helper'

module Ember::Search
  class TicketsControllerTest < ActionController::TestCase
  	include TicketsTestHelper
  	include SearchTestHelper

    def test_result_without_user_access
      @controller.stubs(:api_current_user).raises(ActiveSupport::MessageVerifier::InvalidSignature)
      post :results, construct_params({version: "private", context: "spotlight", term:  Faker::Lorem.words, searchSort:"relevance"})
      assert_response 401
      assert_equal request_error_pattern(:credentials_required).to_json, response.body
    end

    def test_results_with_spotlight_context
      ticket = create_ticket
      stub_private_search_response([ticket]) do
        post :results, construct_params(version: 'private', context: 'spotlight')
      end
      
      assert_response 200
      assert_equal [search_ticket_pattern(ticket)].to_json, response.body
    end

    def test_results_with_created_at_filter_params
      ticket = create_ticket
      stub_private_search_response([ticket]) do
        post :results, construct_params(version: 'private', context: 'spotlight', filter_params: {created_at: "0"})
      end
      assert_response 200
      assert_equal [search_ticket_pattern(ticket)].to_json, response.body
    end

    def test_results_with_custom_field_filter_params
			account = Account.current   
      account.ticket_fields.custom_fields.each(&:destroy)	
      ticket_field = []
      custom_field_name = []
      ticket_field << create_custom_field("test_custom_number", "number")
      custom_field_name << ticket_field.last.name
      account.save
      ticket = create_ticket({custom_field: {"test_custom_number_1": "3"}})
      stub_private_search_response([ticket]) do
        post :results, construct_params(version: 'private', context: 'spotlight', filter_params: {custom_fields: {"test_custom_number_1": "3"}})
      end
      assert_response 200
      assert_equal [search_ticket_pattern(ticket)].to_json, response.body
    end

    def test_results_with_merge_context_and_search_field_display_id
      ticket = create_ticket
      stub_private_search_response([ticket]) do
        post :results, construct_params(version: 'private', context: 'merge', field: 'display_id')
      end
      assert_response 200
      assert_equal [search_ticket_pattern(ticket)].to_json, response.body
    end

    def test_results_with_merge_context_and_search_field_subject
      ticket = create_ticket
      stub_private_search_response([ticket]) do
        post :results, construct_params(version: 'private', context: 'merge', field: 'subject')
      end
      assert_response 200
      assert_equal [search_ticket_pattern(ticket)].to_json, response.body
    end

    def test_results_with_merge_context_and_search_field_requester
      ticket = create_ticket
      stub_private_search_response([ticket]) do
        post :results, construct_params(version: 'private', context: 'merge', field: 'requester')
      end
      assert_response 200
      assert_equal [search_ticket_pattern(ticket)].to_json, response.body
    end

    def test_results_with_recent_tracker_context
      ticket = create_ticket
      stub_private_search_response([ticket]) do
        post :results, construct_params(version: 'private', context: 'recent_tracker')
      end
      assert_response 200
      assert_equal [search_ticket_pattern(ticket)].to_json, response.body
    end

    def test_results_with_restricted_agent_and_shared_ownership
      user = User.current
      permission = user.agent.ticket_permission
   	 	group = create_group_with_agents(Account.current, agent_list: [user.id])
    	user.agent.update_attributes(ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
    	Account.any_instance.stubs(:shared_ownership_enabled?).returns(true)
    	ticket = create_ticket({}, group)
      stub_private_search_response([ticket]) do
        post :results, construct_params(version: 'private', context: 'spotlight')
      end
      user.agent.update_attributes(:ticket_permission => permission)
      Account.any_instance.unstub(:shared_ownership_enabled?)
      assert_response 200
      assert_equal [search_ticket_pattern(ticket)].to_json, response.body
    end
  end
end
