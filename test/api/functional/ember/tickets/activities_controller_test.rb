require_relative '../../../test_helper'
require Rails.root.join('test', 'api', 'helpers', 'archive_ticket_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'advanced_scope_test_helper.rb')

module Ember
  module Tickets
    class ActivitiesControllerTest < ActionController::TestCase
      include ApiTicketsTestHelper
      include TicketActivitiesTestHelper
      include PrivilegesHelper
      include UsersTestHelper
      include ArchiveTicketTestHelper
      include AdvancedScopeTestHelper

      CUSTOM_FIELDS = %w(number checkbox decimal text paragraph dropdown country state city date).freeze

      def setup
        super
        before_all
      end

      @@before_all_run = false
      @@ticket = nil

      def before_all
        # Every test is stubbed so no need to create tickets and agents repeatedly
        @agent   = @account.agents.full_time_support_agents.first.user
        @ticket  = @@ticket || create_ticket(responder_id: @agent.id)
        @rule    = @account.account_va_rules.first

        return if @@before_all_run

        @account.sections.map(&:destroy)
        @account.ticket_fields.custom_fields.each(&:destroy)
        ticket_fields = []
        custom_field_labels = []
        ticket_fields << create_dependent_custom_field(%w[test_custom_country test_custom_state test_custom_city], Random.rand(30..40))
        ticket_fields << create_custom_field_dropdown('test_custom_dropdown', ['Get Smart', 'Pursuit of Happiness', 'Armaggedon'])
        choices_custom_field_labels = ticket_fields.map(&:label)
        CUSTOM_FIELDS.each do |custom_field|
          next if %w(dropdown country state city).include?(custom_field)
          ticket_fields << create_custom_field("test_custom_#{custom_field}", custom_field)
          custom_field_labels << ticket_fields.last.label
        end
        @@before_all_run = true
        @@ticket = @ticket
      end

      def wrap_cname(params)
        { activities: params }
      end

      def test_activity_for_unavailable_ticket
        get :index, controller_params(version: 'private', ticket_id: 10_000)
        assert_response 404
      end

      def test_activity_without_privilege
        remove_privilege(User.current, :manage_tickets)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        assert_response 403
      ensure
        add_privilege(User.current, :manage_tickets)
      end

      def test_activity_thrift_failure
        @controller.stubs(:fetch_activities).returns(false)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        assert_response 500
      end

      def test_property_update_activity
        stub_data = property_update_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(property_update_activity_pattern(stub_data))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_log_and_render_301_archive_with_archive_ticket_link
        enable_archive_tickets do
          create_archive_ticket_with_assoc
          get :index, controller_params(version: 'private', ticket_id: @archive_ticket.display_id)
          assert_response 301
        end
      end

      def test_activity_with_restricted_hash
        stub_data = property_update_activity
        remove_privilege(User.current, :view_contacts)
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(property_update_activity_pattern(stub_data))
        assert_response 200
      ensure
        add_privilege(User.current, :view_contacts)
        @controller.unstub(:fetch_activities)
      end

      def test_invalid_fields_activity
        stub_data = invalid_fields_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(invalid_fields_activity_pattern(stub_data))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_add_note_activity
        @note = create_private_note(@ticket)
        stub_data = add_note_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(note_activity_pattern(stub_data))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_add_tag_activity
        stub_data = tag_activity(true)
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(tag_activity_pattern(stub_data, true))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_remove_tag_activity
        stub_data = tag_activity(false)
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(tag_activity_pattern(stub_data, false))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_spam_ticket_activity
        stub_data = spam_ticket_activity(true)
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(spam_activity_pattern(stub_data))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_unspam_ticket_activity
        stub_data = spam_ticket_activity(false)
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(spam_activity_pattern(stub_data))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_delete_ticket_activity
        stub_data = delete_ticket_activity(true)
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(delete_activity_pattern(stub_data))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_restore_ticket_activity
        stub_data = delete_ticket_activity(false)
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(delete_activity_pattern(stub_data))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_archive_ticket_activity
        stub_data = archive_ticket_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(archive_activity_pattern(stub_data))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_add_watcher_activity
        stub_data = watcher_activity(true)
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(watcher_activity_pattern(stub_data))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_remove_watcher_activity
        stub_data = watcher_activity(false)
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(watcher_activity_pattern(stub_data))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_execute_scenario_activity
        stub_data = execute_scenario_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(execute_scenario_activity_pattern(stub_data))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_add_cc_activity
        stub_data = add_cc_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(add_cc_activity_pattern(stub_data))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_email_to_group_activity
        stub_data = email_to_group_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(email_to_activity_pattern(stub_data, :email_to_group))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_email_to_requester_activity
        stub_data = email_to_requester_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(email_to_activity_pattern(stub_data, :email_to_requester))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_email_to_agent_activity
        stub_data = email_to_agent_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(email_to_activity_pattern(stub_data, :email_to_agent))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_delete_status_activity
        stub_data = delete_status_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(delete_status_activity_pattern(stub_data))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_ticket_merge_target_activity
        @target_ticket = create_ticket(responder_id: @agent.id)
        stub_data = ticket_merge_target_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @target_ticket.display_id)
        match_json(ticket_merge_activity_pattern(stub_data, :ticket_merge_target))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_ticket_merge_source_activity
        @target_ticket = create_ticket(responder_id: @agent.id)
        stub_data = ticket_merge_source_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(ticket_merge_activity_pattern(stub_data, :ticket_merge_source))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_ticket_split_target_activity
        @target_ticket = create_ticket(responder_id: @agent.id)
        stub_data = ticket_split_target_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @target_ticket.display_id)
        match_json(ticket_split_activity_pattern(stub_data, :ticket_split_target))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_ticket_split_source_activity
        @target_ticket = create_ticket(responder_id: @agent.id)
        stub_data = ticket_split_source_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(ticket_split_activity_pattern(stub_data, :ticket_split_source))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_ticket_import_activity
        stub_data = ticket_import_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(ticket_import_activity_pattern(stub_data))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_round_robin_activity
        stub_data = round_robin_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(round_robin_activity_pattern(stub_data))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_timesheet_create_activity
        @timesheet = create_timesheet
        stub_data = timesheet_create_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(create_timesheet_activity_pattern(stub_data))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_timesheet_edit_activity
        @timesheet = create_timesheet
        stub_data = timesheet_edit_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(edit_timesheet_activity_pattern(stub_data))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_timesheet_delete_activity
        @timesheet = create_timesheet
        stub_data = timesheet_delete_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(delete_timesheet_activity_pattern(stub_data))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_empty_actions_activity
        stub_data = empty_action_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json([])
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_skill_name_activity
        stub_data = skill_name_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(skill_name_activity_pattern(stub_data))
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_delete_group_activity
        stub_data = delete_group_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(delete_group_activity_pattern(stub_data))
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_remove_group_activity
        stub_data = remove_group_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(remove_group_activity_pattern(stub_data))
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_remove_agent_activity
        stub_data = remove_agent_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(remove_agent_activity_pattern(stub_data))
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_remove_status_activity
        stub_data = remove_status_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(remove_status_activity_pattern(stub_data))
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_shared_ownership_reset_activity
        stub_data = shared_ownership_reset_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(shared_ownership_reset_activity_pattern(stub_data))
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_delete_agent_activity
        stub_data = delete_agent_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(delete_agent_activity_pattern(stub_data))
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_delete_internal_agent_activity
        stub_data = delete_internal_agent_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(delete_internal_agent_activity_pattern(stub_data))
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_delete_internal_group_activity
        stub_data = delete_internal_group_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(delete_internal_group_activity_pattern(stub_data))
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_ticket_linked_activity
        stub_data = ticket_linked_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(ticket_linked_activity_pattern(stub_data))
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_ticket_unlinked_activity
        stub_data = ticket_unlinked_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(ticket_unlinked_activity_pattern(stub_data))
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_tracker_linked_activity
        stub_data = tracker_linked_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(tracker_linked_activity_pattern(stub_data))
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_tracker_unlinked_activity
        stub_data = tracker_unlinked_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(tracker_unlinked_activity_pattern(stub_data))
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_tracker_reset_activity
        stub_data = tracker_reset_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(tracker_reset_activity_pattern(stub_data))
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_parent_ticket_linked_activity
        stub_data = parent_ticket_linked_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(parent_ticket_linked_activity_pattern(stub_data))
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_parent_ticket_unlinked_activity
        stub_data = parent_ticket_unlinked_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(parent_ticket_unlinked_activity_pattern(stub_data))
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_child_ticket_linked_activity
        stub_data = child_ticket_linked_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(child_ticket_linked_activity_pattern(stub_data))
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_child_ticket_unlinked_activity
        stub_data = child_ticket_unlinked_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(child_ticket_unlinked_activity_pattern(stub_data))
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_parent_ticket_reopened_activity
        stub_data = parent_ticket_reopened_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(parent_ticket_reopened_activity_pattern(stub_data))
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_empty_user_activity
        stub_data = empty_user_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json([])
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_default_system_activity
        stub_data = default_system_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(default_system_activity_pattern(stub_data))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_system_add_note_activity
        stub_data = system_add_note_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(system_add_note_activity_pattern(stub_data))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_system_forward_ticket_activity
        stub_data = system_forward_ticket_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.display_id)
        match_json(system_forward_ticket_activity_pattern(stub_data))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_activity_without_advanced_scope
        Account.any_instance.stubs(:advanced_ticket_scopes_enabled?).returns(false)
        agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
        agent_group = create_agent_group_with_read_access(@account, agent)
        ticket = create_ticket
        ticket.group_id = agent_group.group_id
        ticket.save!
        login_as(agent)
        get :index, controller_params(version: 'private', ticket_id: ticket.display_id)
        assert_response 403
      ensure
        agent.destroy
        Account.any_instance.unstub(:advanced_ticket_scopes_enabled?)
      end

      def test_activity_with_advanced_scope
        Account.any_instance.stubs(:advanced_ticket_scopes_enabled?).returns(true)
        agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
        agent_group = create_agent_group_with_read_access(@account, agent)
        ticket = create_ticket
        ticket.group_id = agent_group.group_id
        ticket.save!
        login_as(agent)
        stub_data = empty_user_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: ticket.display_id)
        assert_response 200
      ensure
        agent.destroy
        Account.any_instance.unstub(:advanced_ticket_scopes_enabled?)
      end
    end
  end
end
