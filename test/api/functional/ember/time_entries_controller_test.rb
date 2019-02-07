require_relative '../../test_helper'
module Ember
  class TimeEntriesControllerTest < ActionController::TestCase
    include TimeEntriesTestHelper
    include UsersTestHelper
    include AccountHelper
    include UsersHelper
    def setup
      super
      @private_api = true
      @private_version = { version: 'private' }
      @account = create_test_account
      Account.any_instance.stubs(:enabled_features_list).returns([:timesheets])
    end

    def teardown
      Account.any_instance.unstub(:enabled_features_list)
    end

    def ticket
      t = Helpdesk::Ticket.joins(:schema_less_ticket).where(deleted: false, spam: false, helpdesk_schema_less_tickets:
                                 { boolean_tc02: false }).order('created_at asc').first
      return t if t
      t = create_ticket
      t.update_attribute(:spam, false)
      t.update_attribute(:deleted, false)
      t
    end

    def wrap_cname(params = {})
      { time_entry: params }
    end

    def test_ticket_time_entries
      new_ticket = ticket
      create_time_entry(ticket_id: new_ticket.id)
      get :ticket_time_entries, controller_params(id: new_ticket.id)
      result_pattern = []
      new_ticket.time_sheets.each do |time_sheet|
        result_pattern << time_entry_pattern({ time_spent: time_sheet.time_spent }, time_sheet)
      end
      match_json(result_pattern)
      assert_response 200
    end

    def test_create_by_saving_timesheet_item
      post :create, construct_params(@private_version.merge(id: ticket.display_id))
      assert_response 201
      time_sheet = Account.current.time_sheets.first
      match_json time_entry_pattern({ time_spent: time_sheet.time_spent }, time_sheet)
    end

    def test_create_without_saving_timesheet_item
      Account.current.time_sheets.any_instance.stubs(:save).returns(false)
      post :create, construct_params(id: ticket.display_id)
      assert_response 400
    end

    def test_toggle_timer
      time_sheet = create_time_entry
      put :toggle_timer, construct_params({ id: time_sheet.id }, {})
      assert_response 200
      timer = Account.current.time_sheets.find(time_sheet.id)
      match_json(time_entry_pattern({ time_spent: timer.time_spent }, timer.reload))
    end

    def test_update_time_sheet_item
      time_sheet = create_time_entry
      put :update, construct_params({ id: time_sheet.id }, time_spent: '09:00')
      assert_response 200
      record = Account.current.time_sheets.find(time_sheet.id)
      match_json time_entry_pattern({ time_spent: record.time_spent }, record)
    end
  end
end
