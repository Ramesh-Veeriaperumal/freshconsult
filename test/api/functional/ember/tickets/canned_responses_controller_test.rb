require_relative '../../../test_helper'
['ticket_helper.rb', 'canned_responses_helper.rb', 'group_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
module Ember
  module Tickets
    class CannedResponsesControllerTest < ActionController::TestCase
      include GroupHelper
      include TicketHelper
      include CannedResponsesHelper
      include CannedResponsesTestHelper

      def setup
        super
        before_all
      end

      def before_all
        file = fixture_file_upload('files/attachment.txt', 'text/plain', :binary)
        @sample_ticket = create_ticket
        @ca_response = create_response(
          title: Faker::Lorem.sentence,
          content_html: 'Hi {{ticket.requester.name}}, Faker::Lorem.paragraph Regards, {{ticket.agent.name}}',
          visibility: Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
          attachments: {
            resource: file,
            description: ''
          }
        )
      end

      def test_show_with_invalid_ticket_id_and_response
        get :show, construct_params({ version: 'private' }, false).merge(id: 0, ticket_id: 0)
        assert_response 404
      end

      def test_show_with_invalid_ticket_id
        get :show, construct_params({ version: 'private' }, false).merge(id: @ca_response.id, ticket_id: 0)
        assert_response 404
      end

      def test_show_with_invalid_response_id
        get :show, construct_params({ version: 'private' }, false).merge(id: 0, ticket_id: @sample_ticket.display_id)
        assert_response 404
      end

      def test_show_with_unauthorized_ticket_id
        user_stub_ticket_permission
        get :show, construct_params({ version: 'private' }, false).merge(id: @ca_response.id, ticket_id: @sample_ticket.display_id)
        user_unstub_ticket_permission
        assert_response 403
        match_json(request_error_pattern(:access_denied))
      end

      def test_show_with_unauthorized_response_id
        Admin::CannedResponses::Response.any_instance.stubs(:visible_to_me?).returns(false)
        get :show, construct_params({ version: 'private' }, false).merge(id: @ca_response.id, ticket_id: @sample_ticket.display_id)
        Admin::CannedResponses::Response.any_instance.unstub(:visible_to_me?)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
      end

      def test_show_with_response_alone
        ca_response_2 = create_response(
          title: Faker::Lorem.sentence,
          content_html: Faker::Lorem.paragraph,
          visibility: Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents]
        )
        get :show, construct_params({ version: 'private' }, false).merge(id: ca_response_2.id, ticket_id: @sample_ticket.display_id)
        assert_response 200
        match_json(canned_responses_evaluated_pattern(false))
      end

      def test_show_with_response_having_attachments
        get :show, construct_params({ version: 'private' }, false).merge(id: @ca_response.id, ticket_id: @sample_ticket.display_id)
        assert_response 200
        match_json(canned_responses_evaluated_pattern(false, @ca_response.attachments_sharable))
      end

      def test_show_response_strict
        evaluated_content = evaluate_response(@ca_response, @sample_ticket)
        get :show, construct_params({ version: 'private' }, false).merge(id: @ca_response.id, ticket_id: @sample_ticket.display_id)
        assert_response 200
        match_json(canned_responses_evaluated_pattern(true, @ca_response.attachments_sharable, evaluated_content))
      end
    end
  end
end
