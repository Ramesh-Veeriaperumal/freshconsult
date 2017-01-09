require_relative '../../../test_helper'
module Ember
  module Tickets
    class ActivitiesControllerTest < ActionController::TestCase
      include TicketsTestHelper
      include TicketActivitiesTestHelper

      CUSTOM_FIELDS = %w(number checkbox decimal text paragraph dropdown country state city date).freeze

      def setup
        super
        before_all
      end

      @@before_all_run = false

      def before_all
        @account.sections.map(&:destroy)
        @agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
        @ticket = create_ticket(responder_id: @agent.id)
        @note   = create_private_note(@ticket)
        @timesheet = create_timesheet
        return if @@before_all_run
        @account.ticket_fields.custom_fields.each(&:destroy)
        @@ticket_fields = []
        @@custom_field_labels = []
        @@ticket_fields << create_dependent_custom_field(%w(test_custom_country test_custom_state test_custom_city))
        @@ticket_fields << create_custom_field_dropdown('test_custom_dropdown', ['Get Smart', 'Pursuit of Happiness', 'Armaggedon'])
        @@choices_custom_field_labels = @@ticket_fields.map(&:label)
        CUSTOM_FIELDS.each do |custom_field|
          next if %w(dropdown country state city).include?(custom_field)
          @@ticket_fields << create_custom_field("test_custom_#{custom_field}", custom_field)
          @@custom_field_labels << @@ticket_fields.last.label
        end
        @@before_all_run = true
      end

      def wrap_cname(params)
        { activities: params }
      end

      def test_activity_for_unavailable_ticket
        get :index, controller_params(version: 'private', ticket_id: 10_000)
        assert_response 404
      end

      def test_activity_thrift_failure
        ticket = create_ticket
        @controller.stubs(:fetch_activities).returns(false)
        get :index, controller_params(version: 'private', ticket_id: @ticket.id)
        assert_response 500
      end

      def test_property_update_activity
        stub_data = property_update_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.id)
        match_json(property_update_activity_pattern(stub_data))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_invalid_fields_activity
        stub_data = invalid_fields_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.id)
        match_json(invalid_fields_activity_pattern(stub_data))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_add_note_activity
        stub_data = add_note_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.id)
        match_json(note_activity_pattern(stub_data))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_add_tag_activity
        stub_data = tag_activity(true)
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.id)
        match_json(tag_activity_pattern(stub_data, true))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_remove_tag_activity
        stub_data = tag_activity(false)
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.id)
        match_json(tag_activity_pattern(stub_data, false))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_spam_ticket_activity
        stub_data = spam_ticket_activity(true)
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.id)
        match_json(spam_activity_pattern(stub_data))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_unspam_ticket_activity
        stub_data = spam_ticket_activity(false)
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.id)
        match_json(spam_activity_pattern(stub_data))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_delete_ticket_activity
        stub_data = delete_ticket_activity(true)
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.id)
        match_json(delete_activity_pattern(stub_data))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_restore_ticket_activity
        stub_data = delete_ticket_activity(false)
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.id)
        match_json(delete_activity_pattern(stub_data))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      # def test_archive_ticket_activity
      # ensure
      #   @controller.unstub(:fetch_activities)
      # end

      def test_add_watcher_activity
        stub_data = watcher_activity(true)
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.id)
        match_json(watcher_activity_pattern(stub_data))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_remove_watcher_activity
        stub_data = watcher_activity(false)
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.id)
        match_json(watcher_activity_pattern(stub_data))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_execute_scenario_activity
        stub_data = execute_scenario_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.id)
        match_json(execute_scenario_activity_pattern(stub_data))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      # def test_add_cc_activity
      #   stub_data = add_cc_activity
      #   @controller.stubs(:fetch_activities).returns(stub_data)
      #   get :index, controller_params(version: 'private', ticket_id: @ticket.id)
      #   match_json(add_cc_activity_pattern(stub_data))
      #   assert_response 200
      # ensure
      #   @controller.unstub(:fetch_activities)
      # end

      # def test_delete_status_activity
      #   ticket = create_ticket
      #   @controller.stubs(:fetch_activities).returns(ticket_import_activity(ticket))
      #   get :index, controller_params(version: 'private', ticket_id: @ticket.id)
      #   assert_response 200
      # ensure
      #   @controller.unstub(:fetch_activities)
      # end

      # def test_ticket_merge_activity
      #   ticket = create_ticket
      #   @controller.stubs(:fetch_activities).returns(ticket_merge_activity(ticket))
      #   get :index, controller_params(version: 'private', ticket_id: @ticket.id)
      #   assert_response 200
      # ensure
      #   @controller.unstub(:fetch_activities)
      # end

      # def test_ticket_split_activity
      #   ticket = create_ticket
      #   @controller.stubs(:fetch_activities).returns(ticket_split_activity)
      #   get :index, controller_params(version: 'private', ticket_id: @ticket.id)
      #   assert_response 200
      # ensure
      #   @controller.unstub(:fetch_activities)
      # end

      # def test_ticket_import_activity
      #   ticket = create_ticket
      #   @controller.stubs(:fetch_activities).returns(ticket_import_activity(ticket))
      #   get :index, controller_params(version: 'private', ticket_id: @ticket.id)
      #   assert_response 200
      # ensure
      #   @controller.unstub(:fetch_activities)
      # end

      # def test_rules_email_to_activity
      #   ticket = create_ticket
      #   @controller.stubs(:fetch_activities).returns(rules_email_to_activity(ticket))
      #   get :index, controller_params(version: 'private', ticket_id: @ticket.id)
      #   assert_response 200
      # ensure
      #   @controller.unstub(:fetch_activities)
      # end

      def test_timesheet_create_activity
        ticket = create_ticket
        stub_data = timesheet_create_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.id)
        match_json(create_timesheet_activity_pattern(stub_data))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_timesheet_edit_activity
        ticket = create_ticket
        stub_data = timesheet_edit_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.id)
        match_json(edit_timesheet_activity_pattern(stub_data))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end

      def test_timesheet_delete_activity
        ticket = create_ticket
        stub_data = timesheet_delete_activity
        @controller.stubs(:fetch_activities).returns(stub_data)
        get :index, controller_params(version: 'private', ticket_id: @ticket.id)
        match_json(delete_timesheet_activity_pattern(stub_data))
        assert_response 200
      ensure
        @controller.unstub(:fetch_activities)
      end
    end
  end
end
