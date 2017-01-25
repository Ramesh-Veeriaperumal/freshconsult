require_relative '../../test_helper'
['canned_responses_helper.rb', 'group_helper.rb', 'agent_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
require_relative "#{Rails.root}/lib/helpdesk_access_methods.rb"

module Ember
  class CannedResponsesControllerTest < ActionController::TestCase
    include GroupHelper
    include CannedResponsesHelper
    include CannedResponsesTestHelper
    include CannedResponseFoldersTestHelper
    include HelpdeskAccessMethods
    include AgentHelper
    include TicketHelper
    include AttachmentsTestHelper

    def setup
      super
      before_all
    end

    def before_all
      file = fixture_file_upload('files/attachment.txt', 'text/plain', :binary)
      @account = Account.first.make_current
      @sample_ticket = create_ticket
      @agent = @account.agents.first.user

      @ca_folder_all = create_cr_folder(name: Faker::Name.name)
      @ca_folder_personal = @account.canned_response_folders.personal_folder.first

      # responses in visible to all folder
      @ca_response_1 = create_canned_response(@ca_folder_all.id)

      # responses in personal folder
      @ca_response_2 = create_canned_response(@ca_folder_personal.id, Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me])

      # responses based on groups
      # @test_group = create_group(@account)
      @ca_response_3 = create_canned_response(@ca_folder_all.id, Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents])

      @ca_response_4 = create_response(
        title: Faker::Lorem.sentence,
        content_html: 'Hi {{ticket.requester.name}}, Faker::Lorem.paragraph Regards, {{ticket.agent.name}}',
        visibility: Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
        attachments: {
          resource: file,
          description: ''
        }
      )
    end

    # tests for show
    # 1. show the response visible to all
    # 2. should show personal responses
    # 3. should not show personal responses of other agents
    # 4. should not show responses visible in particular group to agents not in the group
    # 5. Check with invalid response id

    def test_show_response
      login_as(@agent)
      get :show, controller_params(version: 'private', id: @ca_response_1.id)
      assert_response 200
      match_json(ca_response_show_pattern(@ca_response_1.id))
    end

    def test_show_responses_in_personal_folder
      login_as(@agent)
      get :show, controller_params(version: 'private', id: @ca_response_2.id)
      assert_response 200
      match_json(ca_response_show_pattern(@ca_response_2.id))
    end

    def test_show_personal_responses_of_other_agents
      new_agent = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1)
      login_as(new_agent.user)
      get :show, controller_params(version: 'private', id: @ca_response_2.id)
      assert_response 403
    end

    def test_show_with_group_visibility_response
      new_agent = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1)
      login_as(new_agent.user)
      get :show, controller_params(version: 'private', id: @ca_response_3.id)
      assert_response 403
    end

    def test_show_invalid_folder_id
      get :show, controller_params(version: 'private', id: 0)
      assert_response 404
    end

    def test_show_with_invalid_ticket_id_and_response
      get :show, controller_params(version: 'private', id: 10_000, ticket_id: 10_000, include: 'evaluated_response')
      assert_response 404
    end

    def test_show_with_invalid_ticket_id
      get :show, controller_params(version: 'private', id: @ca_response_1.id, ticket_id: 10_000, include: 'evaluated_response')
      assert_response 404
    end

    def test_show_with_invalid_response_id
      get :show, controller_params(version: 'private', id: 0, ticket_id: @sample_ticket.display_id, include: 'evaluated_response')
      assert_response 404
    end

    def test_show_with_unauthorized_ticket_id
      user_stub_ticket_permission
      get :show, controller_params(version: 'private', id: @ca_response_4.id, ticket_id: @sample_ticket.display_id, include: 'evaluated_response')
      user_unstub_ticket_permission
      assert_response 403
      match_json(request_error_pattern(:access_denied))
    end

    def test_show_with_unauthorized_response_id
      Admin::CannedResponses::Response.any_instance.stubs(:visible_to_me?).returns(false)
      get :show, controller_params(version: 'private', id: @ca_response_1.id, ticket_id: @sample_ticket.display_id, include: 'evaluated_response')
      Admin::CannedResponses::Response.any_instance.unstub(:visible_to_me?)
      assert_response 403
      match_json(request_error_pattern(:access_denied))
    end

    def test_show_with_evaluated_response
      login_as(@agent)
      get :show, controller_params(version: 'private', id: @ca_response_2.id, ticket_id: @sample_ticket.display_id, include: 'evaluated_response')
      assert_response 200
      match_json(ca_response_show_pattern_evaluated_content(@ca_response_2.id, @sample_ticket))
    end

    def test_show_with_evaluated_response_new_ticket
      login_as(@agent)
      get :show, controller_params(version: 'private', id: @ca_response_2.id, include: 'evaluated_response')
      assert_response 200
      match_json(ca_response_show_pattern_new_ticket(@ca_response_2.id))
    end

    def test_show_with_attachments
      login_as(@agent)
      get :show, controller_params(version: 'private', id: @ca_response_4.id, ticket_id: @sample_ticket.display_id, include: 'evaluated_response')
      assert_response 200
      match_json(ca_response_show_pattern_evaluated_content(@ca_response_4.id, @sample_ticket, @ca_response_4.attachments_sharable))
    end

    def test_show_with_empty_include
      login_as(@agent)
      get :show, controller_params(version: 'private', id: @ca_response_2.id, ticket_id: @sample_ticket.display_id, include: '')
      assert_response 400
      match_json([bad_request_error_pattern('include', :not_included, list: CannedResponseConstants::ALLOWED_INCLUDE_PARAMS)])
    end

    def test_show_with_wrong_type_include
      login_as(@agent)
      get :show, controller_params(version: 'private', id: @ca_response_2.id, ticket_id: @sample_ticket.display_id, include: ['test'])
      assert_response 400
      match_json([bad_request_error_pattern('include', :datatype_mismatch, expected_data_type: 'String', prepend_msg: :input_received, given_data_type: 'Array')])
    end

    def test_show_with_invalid_params
      login_as(@agent)
      get :show, controller_params(version: 'private', id: @ca_response_2.id, ticket_id: @sample_ticket.display_id, includ: 'test')
      assert_response 400
      match_json([bad_request_error_pattern('includ', :invalid_field)])
    end

    # tests for Index
    # 1. 404 when there are no ids
    # 2. 404 when the ids are invalid
    # 3. Show for single id
    # 4. Show for mulitple id all valid ones
    # 5. Show empty array for all invalid ones
    # 6. Combine 2 valid ids and and 2 invalid ids
    # 7. Combine 5 valid ids , continued by an invalid then and and 5 more valid ids. Result would have only 9 responses

    def test_index_404_when_no_ids
      get :index, controller_params(version: 'private')
      assert_response 404
    end

    def test_index_404_for_invalid_ids
      get :index, controller_params(version: 'private', ids: 'a,b,c')
      assert_response 404
    end

    def test_index_for_one_ca
      get :index, controller_params(version: 'private', ids: @ca_response_1.id)
      assert_response 200
      match_json([ca_response_show_pattern(@ca_response_1.id)])
    end

    def test_index_for_multiple_ca
      login_as(@agent)
      get :index, controller_params(version: 'private', ids: [@ca_response_1, @ca_response_2].map(&:id).join(', '))
      assert_response 200
      pattern = []
      [@ca_response_1, @ca_response_2].each do |ca|
        pattern << ca_response_show_pattern(ca.id)
      end
      match_json(pattern)
    end

    def test_index_for_multiple_ca_with_inaccessible_ids
      get :index, controller_params(version: 'private', ids: [@ca_response_1, @ca_response_2, @ca_response_3].map(&:id).join(', '))
      assert_response 200
      pattern = []
      [@ca_response_1, @ca_response_2].each do |ca|
        pattern << ca_response_show_pattern(ca.id)
      end
      match_json(pattern)
      # @ca_response_3 will not be present here.
    end

    def test_index_with_just_inaccessible_ids
      get :index, controller_params(version: 'private', ids: [@ca_response_3].map(&:id).join(', '))
      assert_response 404
    end

    def test_index_for_multiple_ca_with_invalid_ids
      get :index, controller_params(version: 'private', ids: [@ca_response_1, @ca_response_2, @ca_response_3].map(&:id).join(', ') << ',a,b,c')
      assert_response 200
      pattern = []
      [@ca_response_1, @ca_response_2].each do |ca|
        pattern << ca_response_show_pattern(ca.id)
      end
      match_json(pattern)
      # @ca_response_3 will not be present here.
    end

    def test_index_for_limit_in_ids
      ca_responses = Array.new(15) { create_canned_response(@ca_folder_all.id) }

      ids_passed = ca_responses.first(10).collect(&:id)
      ids_passed.insert(3, @ca_response_3.id)
      get :index, controller_params(version: 'private', ids: ids_passed.join(','))
      assert_response 200
      pattern = []
      ca_responses.first(9).each do |ca|
        pattern << ca_response_show_pattern(ca.id)
      end
      match_json(pattern)
    end
  end
end
