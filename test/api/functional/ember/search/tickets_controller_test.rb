require_relative '../../../test_helper'

module Ember::Search
  class TicketsControllerTest < ActionController::TestCase
  	include ApiTicketsTestHelper
  	include SearchTestHelper
    include ConversationsTestHelper
    include ArchiveTicketTestHelper
    ARCHIVE_DAYS = 120
    TICKET_UPDATED_DATE = 150.days.ago

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

    def test_resutls_with_include_subject_as_false
      ticket = create_ticket(subject: 'test subject')
      user = User.current
      user.agent_preferences[:search_settings][:tickets][:include_subject] = false
      stub_private_search_response_with_empty_array do
        post :results, construct_params(version: 'private', context: 'spotlight', term: 'subject', search_sort: 'relevance')
      end
      user.agent_preferences[:search_settings][:tickets][:include_subject] = true
      assert_response 200
      assert JSON.parse(response.body).empty?
    end

    def test_results_with_include_description_as_false
      ticket = create_ticket(description: 'test description')
      user = User.current
      user.agent_preferences[:search_settings][:tickets][:include_description] = false
      stub_private_search_response_with_empty_array do
        post :results, construct_params(version: 'private', context: 'spotlight', term: 'description', search_sort: 'relevance')
      end
      user.agent_preferences[:search_settings][:tickets][:include_description] = true
      assert_response 200
      assert JSON.parse(response.body).empty?
    end

    def test_results_with_include_other_properties_as_false
      ticket_field = create_custom_field('king', 'text')
      ticket = create_ticket(custom_field: { king_1: 'Arthur' })
      user = User.current
      user.agent_preferences[:search_settings][:tickets][:include_other_properties] = false
      stub_private_search_response_with_empty_array do
        post :results, construct_params(version: 'private', context: 'spotlight', term: 'Arthur', searchSort: 'relevance')
      end
      user.agent_preferences[:search_settings][:tickets][:include_other_properties] = true
      assert_response 200
      assert JSON.parse(response.body).empty?
    ensure
      ticket_field.try(:destroy)
    end

    def test_results_with_include_notes_as_false
      ticket = create_ticket
      user = User.current
      conversation = create_note(user_id: user.id, ticket_id: ticket.id, body: 'Addition of note')
      user.agent_preferences[:search_settings][:tickets][:include_notes] = false
      stub_private_search_response_with_empty_array do
        post :results, construct_params(version: 'private', context: 'spotlight', term: 'note', search_sort: 'relevance')
      end
      user.agent_preferences[:search_settings][:tickets][:include_notes] = true
      assert_response 200
      assert JSON.parse(response.body).empty?
    end

    def test_results_with_include_attachment_names_as_false
      ticket = create_ticket
      user = User.current
      ticket.attachments << create_attachment(attachable_type: 'UserDraft', attachable_id: user.id)
      user.agent_preferences[:search_settings][:tickets][:include_attachment_names] = false
      stub_private_search_response_with_empty_array do
        post :results, construct_params(version: 'private', context: 'spotlight', term: 'attachment.txt', search_sort: 'relevance')
      end
      user.agent_preferences[:search_settings][:tickets][:include_attachment_names] = true
      assert_response 200
      assert JSON.parse(response.body).empty?
    end

    def test_results_with_archive_as_false
      ticket = create_ticket
      user = User.current
      @account.enable_ticket_archiving(ARCHIVE_DAYS)
      @account.features.send(:archive_tickets).create
      create_archive_ticket_with_assoc(
        created_at: TICKET_UPDATED_DATE,
        updated_at: TICKET_UPDATED_DATE,
        create_association: true
      )
      user.agent_preferences[:search_settings][:tickets][:archive] = false
      stub_private_search_response_with_empty_array do
        post :results, construct_params(version: 'private', context: 'spotlight', term: @archive_ticket.id.to_s, search_sort: 'relevance')
      end
      user.agent_preferences[:search_settings][:tickets][:archive] = true
      assert_response 200
      assert JSON.parse(@response.body).empty?
    ensure
      cleanup_archive_ticket(@archive_ticket)
    end

    def test_results_without_archive_tickets_feature
      ticket = create_ticket
      user = User.current
      @account.enable_ticket_archiving(ARCHIVE_DAYS)
      @account.features.send(:archive_tickets).create
      create_archive_ticket_with_assoc(
        created_at: TICKET_UPDATED_DATE,
        updated_at: TICKET_UPDATED_DATE,
        create_association: true
      )
      Account.any_instance.stubs(:archive_tickets_enabled?).returns(false)
      stub_private_search_response_with_empty_array do
        post :results, construct_params(version: 'private', context: 'spotlight', term: @archive_ticket.id.to_s, search_sort: 'relevance')
      end
      assert_response 200
      assert JSON.parse(response.body).empty?
      Account.any_instance.unstub(:archive_tickets_enabled?)
    ensure
      cleanup_archive_ticket(@archive_ticket)
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

    def test_results_with_exact_match
      ticket = create_ticket(subject: 'My ticket123')
      stub_private_search_response([ticket]) do
        post :results, construct_params(version: 'private', context: 'spotlight', term: "\"#{ticket.subject}\"")
      end
      assert_response 200
      assert_equal [search_ticket_pattern(ticket)].to_json, response.body
    end

    def test_results_with_custom_field_filter_params_exact_match
      account = Account.current
      account.ticket_fields.custom_fields.each(&:destroy)
      ticket_field = []
      custom_field_name = []
      ticket_field << create_custom_field('test_custom_number', 'number')
      custom_field_name << ticket_field.last.name
      account.save
      ticket = create_ticket(subject: 'My ticket123', custom_field: { 'test_custom_number_1': '3' })
      create_ticket(subject: 'My ticket', custom_field: { 'test_custom_number_1': '3' })
      stub_private_search_response([ticket]) do
        post :results, construct_params(version: 'private', context: 'spotlight', term: "\"#{ticket.subject}\"", filter_params: { custom_fields: { 'test_custom_number_1': '3' } })
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

    def test_custom_fields_in_response
      Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
      ticket_field = create_custom_field('custom_date_time_test', 'date_time')
      ticket = create_ticket(custom_field: { 'custom_date_time_test_1': '2019-10-10T12:23:37Z' })
      stub_private_search_response([ticket]) do
        post :results, construct_params(version: 'private', context: 'spotlight', searchSort: 'relevance', include: 'custom_fields', term: ticket.subject)
      end
      assert_response 200
      assert_equal JSON.parse(response.body)[0]['custom_fields']['custom_date_time_test'], '2019-10-10T12:23:37Z'
    ensure
      Account.any_instance.unstub(:field_service_management_enabled?)
      ticket_field.try(:destroy)
    end

    def test_invalid_include_parameter
      post :results, construct_params(version: 'private', context: 'spotlight', searchSort: 'relevance', include: 'some_fields')
      assert_response 400
      match_json([bad_request_error_pattern('include', :not_included, list: SearchTicketValidation::ALLOWED_INCLUDE_PARAMS.join(','), code: :invalid_value)])
    end

    def test_results_with_valid_params_only_count
      ticket = create_ticket
      stub_private_search_response([ticket]) do
        post :results, construct_params(version: 'private', only: 'count')
      end
      assert_response 200
      assert_equal response.api_meta[:count], 1
      match_json []
    end

    def test_results_with_valid_params_only_count_with_filter_params
      account = Account.current
      account.ticket_fields.custom_fields.each(&:destroy)
      ticket_field = []
      custom_field_name = []
      ticket_field << create_custom_field('test_custom_number', 'number')
      custom_field_name << ticket_field.last.name
      account.save
      ticket = create_ticket(custom_field: { 'test_custom_number_1' => '3' })
      stub_private_search_response([ticket]) do
        post :results, construct_params(version: 'private', only: 'count', filter_params: { custom_fields: { 'test_custom_number_1' => '3' } })
      end
      assert_response 200
      assert_equal response.api_meta[:count], 1
      match_json []
    end

    def test_ember_results_with_restricted_agent_with_scope
      user = User.current
      permission = user.agent.ticket_permission
      group = create_group_with_agents(Account.current, agent_list: [user.id])
      user.agent.update_attributes(ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
      Account.any_instance.stubs(:advanced_scope_enabled?).returns(true)
      ticket = create_ticket({ priority: 1 }, group)
      stub_private_search_response([ticket]) do
        post :results, construct_params(version: 'private', context: 'merge', field: 'display_id')
      end
      response = parse_response @response.body
      assert_response 200
      assert_equal ticket.display_id, response[0]['id']
      user.agent.update_attributes(ticket_permission: permission)
      Account.any_instance.unstub(:advanced_scope_enabled?)
    ensure
      group.destroy if group.present?
      ticket.destroy if ticket.present?
    end

    def test_ember_results_with_restricted_agent_and_shared_ownership_with_scope
      user = User.current
      permission = user.agent.ticket_permission
      group = create_group_with_agents(Account.current, agent_list: [user.id])
      user.agent.update_attributes(ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
      Account.any_instance.stubs(:shared_ownership_enabled?).returns(true)
      Account.any_instance.stubs(:advanced_scope_enabled?).returns(true)
      ticket = create_ticket({ status: 1 }, group)
      stub_private_search_response([ticket]) do
        post :results, construct_params(version: 'private', context: 'merge', field: 'display_id')
      end
      response = parse_response @response.body
      assert_response 200
      assert_equal ticket.display_id, response[0]['id']
      user.agent.update_attributes(ticket_permission: permission)
      Account.any_instance.unstub(:advanced_scope_enabled?)
      Account.any_instance.unstub(:shared_ownership_enabled?)
    ensure
      group.destroy if group.present?
      ticket.destroy if ticket.present?
    end
  end
end
