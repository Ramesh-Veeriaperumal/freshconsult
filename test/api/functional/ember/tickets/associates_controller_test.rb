require_relative '../../../test_helper'
module Ember
  module Tickets
    class AssociatesControllerTest < ActionController::TestCase
      include ApiTicketsTestHelper
      include CannedResponsesTestHelper
      include AdvancedTicketingTestHelper

      # Tests for prime association for related/child tickets
      # 1. valid related/child ticket id
      # 2. invalid related/child ticket id
      # 3. non-existant ticket id
      # 4. feature is not available

      def test_link_tickets_prime_association
        enable_adv_ticketing([:link_tickets]) do
          create_linked_tickets
          get :prime_association, construct_params({ version: 'private', id: @ticket_id }, false)
          assert_response 200
          related_ticket = Helpdesk::Ticket.where(display_id: @ticket_id).first
          match_json(prime_association_pattern(related_ticket))
        end
      end

      def test_link_tickets_prime_association_with_broadcast_message
        enable_adv_ticketing([:link_tickets]) do
          create_linked_tickets
          broadcast_note = create_broadcast_note(@tracker_id)
          create_broadcast_message(@tracker_id, broadcast_note.id)
          get :prime_association, construct_params({ version: 'private', id: @ticket_id }, false)
          assert_response 200
          related_ticket = Helpdesk::Ticket.where(display_id: @ticket_id).first
          pattern = prime_association_pattern(related_ticket).merge(latest_broadcast_pattern(@tracker_id))
          match_json(pattern)
        end
      end

      def test_link_tickets_prime_association_with_non_existant_ticket
        enable_adv_ticketing([:link_tickets]) do
          get :prime_association, construct_params({ version: 'private', id: 0 }, false)
          assert_response 404
        end
      end

      def test_link_tickets_prime_association_with_no_tracker_ticket
        enable_adv_ticketing([:link_tickets]) do
          ticket = create_ticket
          get :prime_association, construct_params({ version: 'private', id: ticket.display_id }, false)
          assert_response 404
        end
      end

      def test_link_tickets_prime_association_with_invalid_ticket
        enable_adv_ticketing([:link_tickets]) do
          create_linked_tickets
          get :prime_association, construct_params({ version: 'private', id: @tracker_id }, false)
          assert_response 404
        end
      end

      def test_link_tickets_prime_association_without_permission
        enable_adv_ticketing([:link_tickets]) do
          create_linked_tickets
          user_stub_ticket_permission
          get :prime_association, construct_params({ version: 'private', id: @ticket_id }, false)
          assert_response 403
          user_unstub_ticket_permission
        end
      end

      def test_link_tickets_prime_association_without_feature
        enable_adv_ticketing([:link_tickets]) do
          create_linked_tickets
        end
        disable_adv_ticketing([:link_tickets])
        get :prime_association, construct_params({ version: 'private', id: @ticket_id }, false)
        assert_response 403
        match_json(request_error_pattern(:require_feature, feature: 'Link Tickets'))
      end

      def test_parent_child_prime_association
        enable_adv_ticketing([:parent_child_tickets]) do
          create_parent_child_tickets
          get :prime_association, construct_params({ version: 'private', id: @child_ticket.display_id }, false)
          assert_response 200
          match_json(prime_association_pattern(@child_ticket))
        end
      end

      def test_parent_child_prime_association_with_non_existant_ticket
        enable_adv_ticketing([:parent_child_tickets]) do
          get :prime_association, construct_params({ version: 'private', id: 0 }, false)
          assert_response 404
        end
      end

      def test_parent_child_prime_association_with_no_parent_ticket
        enable_adv_ticketing([:parent_child_tickets]) do
          ticket = create_ticket
          get :prime_association, construct_params({ version: 'private', id: ticket.display_id }, false)
          assert_response 404
        end
      end

      def test_parent_child_prime_association_with_invalid_ticket
        enable_adv_ticketing([:parent_child_tickets]) do
          create_parent_child_tickets
          get :prime_association, construct_params({ version: 'private', id: @parent_ticket.display_id }, false)
          assert_response 404
        end
      end

      def test_parent_child_prime_association_without_permission
        enable_adv_ticketing([:parent_child_tickets]) do
          create_parent_child_tickets
          user_stub_ticket_permission
          get :prime_association, construct_params({ version: 'private', id: @child_ticket.display_id }, false)
          assert_response 403
          user_unstub_ticket_permission
        end
      end

      def test_parent_child_prime_association_without_feature
        enable_adv_ticketing([:parent_child_tickets]) do
          create_parent_child_tickets
        end
        disable_adv_ticketing([:parent_child_tickets])
        Account.current.instance_variable_set('@pc', false) # Memoize is used. Hence setting it to false once the feature is disabled.
        get :prime_association, construct_params({ version: 'private', id: @child_ticket.display_id }, false)
        assert_response 403
        match_json(request_error_pattern(:require_feature, feature: 'Parent Child Tickets and Field Service Management'))
      end

      # Tests for associated tickets for tracker/parent tickets
      # 1. valid tracker/parent ticket id
      # 2. invalid tracker/parent ticket id
      # 3. non-existant ticket id
      # 4. feature is not available
      # 5. access to ticket not available

      def test_link_tickets_associations
        enable_adv_ticketing([:link_tickets]) do
          create_linked_tickets
          get :associated_tickets, construct_params({ version: 'private', id: @tracker_id }, false)
          assert_response 200
          tracker_ticket = Helpdesk::Ticket.where(display_id: @tracker_id).first
          match_json(associations_pattern(tracker_ticket))
        end
      end

      def test_link_tickets_associations_without_associates
        enable_adv_ticketing([:link_tickets]) do
          create_linked_tickets
          Helpdesk::Ticket.any_instance.stubs(:associates=).returns(true)
          Helpdesk::Ticket.any_instance.stubs(:associates).returns([])
          get :associated_tickets, construct_params({ version: 'private', id: @tracker_id }, false)
          assert_response 200
          assert JSON.parse(response.body).empty?
        end
      end

      def test_link_tickets_associations_with_non_existant_ticket
        enable_adv_ticketing([:link_tickets]) do
          get :associated_tickets, construct_params({ version: 'private', id: 0 }, false)
          assert_response 404
        end
      end

      def test_link_tickets_associations_with_no_tracker_ticket
        enable_adv_ticketing([:link_tickets]) do
          ticket = create_ticket
          get :associated_tickets, construct_params({ version: 'private', id: ticket.display_id }, false)
          assert_response 404
        end
      end

      def test_link_tickets_associations_with_invalid_ticket
        enable_adv_ticketing([:link_tickets]) do
          create_linked_tickets
          get :associated_tickets, construct_params({ version: 'private', id: @ticket_id }, false)
          assert_response 404
        end
      end

      def test_link_tickets_associations_without_permission
        enable_adv_ticketing([:link_tickets]) do
          create_linked_tickets
          user_stub_ticket_permission
          get :associated_tickets, construct_params({ version: 'private', id: @tracker_id }, false)
          assert_response 403
          user_unstub_ticket_permission
        end
      end

      def test_link_tickets_associations_without_feature
        enable_adv_ticketing([:link_tickets]) do
          create_linked_tickets
        end
        disable_adv_ticketing([:link_tickets])
        get :associated_tickets, construct_params({ version: 'private', id: @tracker_id }, false)
        assert_response 403
        match_json(request_error_pattern(:require_feature, feature: 'Link Tickets'))
      end

      def test_parent_child_associations
        enable_adv_ticketing([:parent_child_tickets]) do
          create_parent_child_tickets
          Helpdesk::Ticket.any_instance.stubs(:associates=).returns(true)
          Helpdesk::Ticket.any_instance.stubs(:associates).returns([@child_ticket.display_id])
          get :associated_tickets, construct_params({ version: 'private', id: @parent_ticket.display_id }, false)
          assert_response 200
          match_json(associations_pattern(@parent_ticket))
        end
      end

      def test_parent_child_associations_without_associates
        enable_adv_ticketing([:parent_child_tickets]) do
          create_parent_child_tickets
          Helpdesk::Ticket.any_instance.stubs(:associates=).returns(true)
          Helpdesk::Ticket.any_instance.stubs(:associates).returns([])
          get :associated_tickets, construct_params({ version: 'private', id: @parent_ticket.display_id }, false)
          assert_response 200
          assert JSON.parse(response.body).empty?
        end
      end

      def test_parent_child_associations_with_non_existant_ticket
        enable_adv_ticketing([:parent_child_tickets]) do
          get :associated_tickets, construct_params({ version: 'private', id: 0 }, false)
          assert_response 404
        end
      end

      def test_parent_child_associations_with_no_child_ticket
        enable_adv_ticketing([:parent_child_tickets]) do
          ticket = create_ticket
          get :associated_tickets, construct_params({ version: 'private', id: ticket.display_id }, false)
          assert_response 404
        end
      end

      def test_parent_child_associations_with_invalid_ticket
        enable_adv_ticketing([:parent_child_tickets]) do
          create_parent_child_tickets
          get :associated_tickets, construct_params({ version: 'private', id: @child_ticket.display_id }, false)
          assert_response 404
        end
      end

      def test_parent_child_associations_without_permission
        enable_adv_ticketing([:parent_child_tickets]) do
          create_parent_child_tickets
          user_stub_ticket_permission
          get :associated_tickets, construct_params({ version: 'private', id: @parent_ticket.display_id }, false)
          assert_response 403
          user_unstub_ticket_permission
        end
      end

      def test_parent_child_associations_without_feature
        enable_adv_ticketing([:parent_child_tickets]) do
          create_parent_child_tickets
        end
        disable_adv_ticketing([:parent_child_tickets])
        Account.current.instance_variable_set('@pc', false) # memoize is used, hence setting it to false once the feature is disabled.
        get :associated_tickets, construct_params({ version: 'private', id: @parent_ticket.display_id }, false)
        assert_response 403
        match_json(request_error_pattern(:require_feature, feature: 'Parent Child Tickets and Field Service Management'))
      end

      def test_associations_with_service_task_type
        enable_adv_ticketing([:field_service_management]) do
          enable_fsm do
            begin
              perform_fsm_operations
              Account.any_instance.stubs(:disable_old_ui_enabled?).returns(true)
              child_ticket_ids = create_advanced_tickets
              Helpdesk::Ticket.any_instance.stubs(:associates=).returns(true)
              Helpdesk::Ticket.any_instance.stubs(:associates).returns(child_ticket_ids)
              get :associated_tickets, construct_params({ version: 'private', id: @parent_ticket.display_id, type: 'Service Task' }, false)
              assert_response 200
              match_json(associations_pattern(@parent_ticket))
              Helpdesk::Ticket.any_instance.unstub(:associates=)
              Helpdesk::Ticket.any_instance.unstub(:associates)
            ensure
              Account.any_instance.unstub(:disable_old_ui_enabled?)
            end
          end
        end
      end

      def test_associations_with_empty_service_tasks
        enable_adv_ticketing([:field_service_management]) do
          enable_fsm do
            begin
              Account.any_instance.stubs(:disable_old_ui_enabled?).returns(true)
              perform_fsm_operations
              create_parent_child_tickets
              Helpdesk::Ticket.any_instance.stubs(:associates=).returns(true)
              Helpdesk::Ticket.any_instance.stubs(:associates).returns([@child_ticket.display_id])
              get :associated_tickets, construct_params({ version: 'private', id: @parent_ticket.display_id, type: 'Service Task' }, false)
              assert_response 200
              Helpdesk::Ticket.any_instance.unstub(:associates=)
              Helpdesk::Ticket.any_instance.unstub(:associates)
              match_json([])
            ensure
              Account.any_instance.unstub(:disable_old_ui_enabled?)
            end
          end
        end
      end

      def test_associations_with_invalid_ticket_type
        enable_adv_ticketing([:field_service_management]) do
          create_parent_child_tickets
          Helpdesk::Ticket.any_instance.stubs(:associates=).returns(true)
          Helpdesk::Ticket.any_instance.stubs(:associates).returns([@child_ticket.display_id])
          get :associated_tickets, construct_params({ version: 'private', id: @parent_ticket.display_id, type: 'Service Task' }, false)
          assert_response 400
          Helpdesk::Ticket.any_instance.unstub(:associates=)
          Helpdesk::Ticket.any_instance.unstub(:associates)
        end
      end

      def test_association_count_with_service_task
        enable_adv_ticketing([:field_service_management]) do
          enable_fsm do
            begin
              Account.any_instance.stubs(:disable_old_ui_enabled?).returns(true)
              perform_fsm_operations
              child_ticket_ids = create_advanced_tickets
              Helpdesk::Ticket.any_instance.stubs(:associates=).returns(true)
              Helpdesk::Ticket.any_instance.stubs(:associates).returns(child_ticket_ids)
              get :associated_tickets_count, construct_params({ version: 'private', id: @parent_ticket.display_id, type: 'Service Task' }, false)
              assert_response 200
              Helpdesk::Ticket.any_instance.unstub(:associates=)
              Helpdesk::Ticket.any_instance.unstub(:associates)
              match_json('count' => 1)
            ensure
              Account.any_instance.unstub(:disable_old_ui_enabled?)
            end
          end
        end
      end

      def test_association_count_filter_with_multiple_child
        enable_adv_ticketing([:field_service_management]) do
          enable_fsm do
            begin
              Account.any_instance.stubs(:disable_old_ui_enabled?).returns(true)
              perform_fsm_operations
              child_ticket_ids = create_advanced_tickets(fsm: 3)
              Helpdesk::Ticket.any_instance.stubs(:associates=).returns(true)
              Helpdesk::Ticket.any_instance.stubs(:associates).returns(child_ticket_ids)
              get :associated_tickets_count, construct_params({ version: 'private', id: @parent_ticket.display_id, type: 'Service Task' }, false)
              assert_response 200
              Helpdesk::Ticket.any_instance.unstub(:associates=)
              Helpdesk::Ticket.any_instance.unstub(:associates)
              match_json('count' => 3)
            ensure
              Account.any_instance.unstub(:disable_old_ui_enabled?)
            end
          end
        end
      end

      def test_association_count_without_filter
        enable_adv_ticketing([:field_service_management]) do
          enable_fsm do
            begin
              Account.any_instance.stubs(:disable_old_ui_enabled?).returns(true)
              perform_fsm_operations
              child_ticket_ids = create_advanced_tickets(fsm: 1, pc: 1)
              Helpdesk::Ticket.any_instance.stubs(:associates=).returns(true)
              Helpdesk::Ticket.any_instance.stubs(:associates).returns(child_ticket_ids)
              get :associated_tickets_count, construct_params({ version: 'private', id: @parent_ticket.display_id }, false)
              assert_response 200
              Helpdesk::Ticket.any_instance.unstub(:associates=)
              Helpdesk::Ticket.any_instance.unstub(:associates)
              match_json('count' => 2)
            ensure
              Account.any_instance.unstub(:disable_old_ui_enabled?)
            end
          end
        end
      end

      def test_association_count_without_the_ticket
        enable_adv_ticketing([:field_service_management]) do
          enable_fsm do
            begin
              Account.any_instance.stubs(:disable_old_ui_enabled?).returns(true)
              perform_fsm_operations
              ticket = create_ticket
              get :associated_tickets_count, construct_params({ version: 'private', id: ticket.display_id }, false)
              assert_response 404
            ensure
              Account.any_instance.unstub(:disable_old_ui_enabled?)
            end
          end
        end
      end

      def test_link_tickets_association_count
        enable_adv_ticketing([:link_tickets]) do
          create_linked_tickets
          Helpdesk::Ticket.any_instance.stubs(:associates=).returns(true)
          Helpdesk::Ticket.any_instance.stubs(:associates).returns([])
          get :associated_tickets_count, construct_params({ version: 'private', id: @tracker_id, type: 'Question' }, false)
          assert_response 400
        end
      end
    end
  end
end
