require_relative '../../../test_helper'
module Ember
  module Tickets
    class AssociatesControllerTest < ActionController::TestCase
      include TicketsTestHelper
      include CannedResponsesTestHelper

      def test_link_ticket_to_tracker
        enable_adv_ticketing(:link_tickets) do
          tracker_id = create_tracker_ticket.display_id
          ticket_id = create_ticket.display_id
          put :link, construct_params({ version: 'private', id: ticket_id, tracker_id: tracker_id }, false)
          assert_response 204
          ticket = Helpdesk::Ticket.find_by_display_id(ticket_id)
          assert ticket.related_ticket?
        end
      end

      def test_link_to_invalid_tracker
        enable_adv_ticketing(:link_tickets) do
          tracker_id = create_ticket.display_id
          ticket_id = create_ticket.display_id
          put :link, construct_params({ version: 'private', id: ticket_id, tracker_id: tracker_id }, false)
          pattern = ['tracker_id', nil, { append_msg: I18n.t('ticket.link_tracker.permission_denied') }]
          assert_link_failure(ticket_id, pattern)
        end
      end

      def test_link_to_spammed_tracker
        enable_adv_ticketing(:link_tickets) do
          tracker = create_tracker_ticket
          tracker.update_attributes(spam: true)
          ticket_id = create_ticket.display_id
          put :link, construct_params({ version: 'private', id: ticket_id, tracker_id: tracker.display_id }, false)
          pattern = ['tracker_id', nil, { append_msg: I18n.t('ticket.link_tracker.permission_denied') }]
          assert_link_failure(ticket_id, pattern)
        end
      end

      def test_link_to_deleted_tracker
        enable_adv_ticketing(:link_tickets) do
          tracker = create_tracker_ticket
          tracker.update_attributes(deleted: true)
          ticket_id = create_ticket.display_id
          put :link, construct_params({ version: 'private', id: ticket_id, tracker_id: tracker.display_id }, false)
          pattern = ['tracker_id', nil, { append_msg: I18n.t('ticket.link_tracker.permission_denied') }]
          assert_link_failure(ticket_id, pattern)
        end
      end

      def test_link_ticket_without_permission
        enable_adv_ticketing(:link_tickets) do
          ticket_id = create_ticket.display_id
          tracker_id = create_tracker_ticket.display_id
          user_stub_ticket_permission
          put :link, construct_params({ version: 'private', id: ticket_id, tracker_id: tracker_id }, false)
          assert_response 403
          ticket = Helpdesk::Ticket.find_by_display_id(ticket_id)
          assert !ticket.related_ticket?
          user_unstub_ticket_permission
        end
      end

      def test_link_with_invalid_params
        enable_adv_ticketing(:link_tickets) do
          ticket_id = create_ticket.display_id
          put :link, construct_params({ version: 'private', id: ticket_id }, false)
          assert_link_failure(ticket_id)
        end
      end

      def test_link_a_deleted_ticket
        enable_adv_ticketing(:link_tickets) do
          ticket = create_ticket
          ticket.update_attributes(deleted: true)
          ticket_id = ticket.display_id
          tracker_id = create_tracker_ticket.display_id
          put :link, construct_params({ version: 'private', id: ticket_id, tracker_id: tracker_id }, false)
          pattern = [:id, :unable_to_perform]
          assert_link_failure(ticket_id, pattern)
        end
      end

      def test_link_a_spammed_ticket
        enable_adv_ticketing(:link_tickets) do
          ticket = create_ticket
          ticket.update_attributes(spam: true)
          tracker_id = create_tracker_ticket.display_id
          put :link, construct_params({ version: 'private', id: ticket.display_id, tracker_id: tracker_id }, false)
          pattern = [:id, :unable_to_perform]
          assert_link_failure(ticket.display_id, pattern)
        end
      end

      def test_link_an_associated_ticket_to_tracker
        enable_adv_ticketing(:link_tickets) do
          ticket = create_ticket
          ticket.update_attributes(association_type: 1)
          tracker_id = create_tracker_ticket.display_id
          put :link, construct_params({ version: 'private', id: ticket.display_id, tracker_id: tracker_id }, false)
          assert_link_failure(nil, [:id, :unable_to_perform])
        end
      end

      def test_link_non_existant_ticket_to_tracker
        enable_adv_ticketing(:link_tickets) do
          ticket = create_ticket
          ticket_id = ticket.display_id
          ticket.destroy
          tracker_id = create_tracker_ticket.display_id
          put :link, construct_params({ version: 'private', id: ticket_id, tracker_id: tracker_id }, false)
          assert_response 400
        end
      end

      def test_link_without_link_tickets_feature
        disable_adv_ticketing(:link_tickets) if Account.current.launched?(:link_tickets)
        ticket = create_ticket
        ticket_id = ticket.display_id
        tracker_id = create_tracker_ticket.display_id
        put :link, construct_params({ version: 'private', id: ticket_id, tracker_id: tracker_id }, false)
        assert_response 403
        assert !ticket.related_ticket?
        match_json(request_error_pattern(:require_feature, feature: 'Link Tickets'))
      end

      # Tests for prime association for related/child tickets
      # 1. valid related/child ticket id
      # 2. invalid related/child ticket id
      # 3. non-existant ticket id
      # 4. feature is not available

      def test_link_tickets_prime_association
        enable_adv_ticketing(:link_tickets) do
          tracker = create_tracker_ticket
          ticket = create_ticket
          put :link, construct_params({ version: 'private', id: ticket.display_id, tracker_id: tracker.display_id }, false)
          ticket.reload
          get :prime_association, construct_params({ version: 'private', id: ticket.display_id }, false)
          assert_response 200
          match_json(prime_association_pattern(ticket))
        end
      end

      def test_link_tickets_prime_association_with_non_existant_ticket
        enable_adv_ticketing(:link_tickets) do
          get :prime_association, construct_params({ version: 'private', id: 0 }, false)
          assert_response 404
        end
      end

      def test_link_tickets_prime_association_with_no_tracker_ticket
        enable_adv_ticketing(:link_tickets) do
          ticket = create_ticket
          get :prime_association, construct_params({ version: 'private', id: ticket.display_id }, false)
          assert_response 400
          match_json([bad_request_error_pattern(:id, :unable_to_perform)])
        end
      end

      def test_link_tickets_prime_association_with_invalid_ticket
        enable_adv_ticketing(:link_tickets) do
          tracker = create_tracker_ticket
          ticket = create_ticket
          put :link, construct_params({ version: 'private', id: ticket.display_id, tracker_id: tracker.display_id }, false)
          get :prime_association, construct_params({ version: 'private', id: tracker.display_id }, false)
          assert_response 400
          match_json([bad_request_error_pattern(:id, :unable_to_perform)])
        end
      end

      def test_link_tickets_prime_association_without_permission
        enable_adv_ticketing(:link_tickets) do
          tracker = create_tracker_ticket
          ticket = create_ticket
          put :link, construct_params({ version: 'private', id: ticket.display_id, tracker_id: tracker.display_id }, false)
          user_stub_ticket_permission
          get :prime_association, construct_params({ version: 'private', id: ticket.display_id }, false)
          assert_response 403
          user_unstub_ticket_permission
        end
      end

      def test_link_tickets_prime_association_without_feature
        ticket = create_ticket
        enable_adv_ticketing(:link_tickets) do
          tracker = create_tracker_ticket
          put :link, construct_params({ version: 'private', id: ticket.display_id, tracker_id: tracker.display_id }, false)
        end
        disable_adv_ticketing(:link_tickets)
        get :prime_association, construct_params({ version: 'private', id: ticket.display_id }, false)
        assert_response 403
        match_json(request_error_pattern(:require_feature, feature: 'Link Tickets'))
      end

      def test_parent_child_prime_association
        enable_adv_ticketing(:parent_child_tickets) do
          parent_ticket = create_parent_ticket
          child_ticket = create_ticket(assoc_parent_id: parent_ticket.display_id)
          get :prime_association, construct_params({ version: 'private', id: child_ticket.display_id }, false)
          assert_response 200
          match_json(prime_association_pattern(child_ticket))
        end
      end

      def test_parent_child_prime_association_with_non_existant_ticket
        enable_adv_ticketing(:parent_child_tickets) do
          get :prime_association, construct_params({ version: 'private', id: 0 }, false)
          assert_response 404
        end
      end

      def test_parent_child_prime_association_with_no_parent_ticket
        enable_adv_ticketing(:parent_child_tickets) do
          ticket = create_ticket
          get :prime_association, construct_params({ version: 'private', id: ticket.display_id }, false)
          assert_response 400
          match_json([bad_request_error_pattern(:id, :unable_to_perform)])
        end
      end

      def test_parent_child_prime_association_with_invalid_ticket
        enable_adv_ticketing(:parent_child_tickets) do
          parent_ticket = create_parent_ticket
          child_ticket = create_ticket(assoc_parent_id: parent_ticket.display_id)
          get :prime_association, construct_params({ version: 'private', id: parent_ticket.display_id }, false)
          assert_response 400
          match_json([bad_request_error_pattern(:id, :unable_to_perform)])
        end
      end

      def test_parent_child_prime_association_without_permission
        enable_adv_ticketing(:parent_child_tickets) do
          parent_ticket = create_parent_ticket
          child_ticket = create_ticket(assoc_parent_id: parent_ticket.display_id)
          user_stub_ticket_permission
          get :prime_association, construct_params({ version: 'private', id: child_ticket.display_id }, false)
          assert_response 403
          user_unstub_ticket_permission
        end
      end

      def test_parent_child_prime_association_without_feature
        parent_ticket = create_parent_ticket
        enable_adv_ticketing(:parent_child_tickets) do
          @child_ticket = create_ticket(assoc_parent_id: [parent_ticket.display_id])
        end
        disable_adv_ticketing(:parent_child_tickets)
        Account.current.instance_variable_set('@pc', false) # Memoize is used. Hence setting it to false once the feature is disabled.
        get :prime_association, construct_params({ version: 'private', id: @child_ticket.display_id }, false)
        assert_response 403
        match_json(request_error_pattern(:require_feature, feature: 'Parent Child Tickets'))
      end
    end
  end
end
