require_relative '../../../api/unit_test_helper'
require Rails.root.join('spec', 'support', 'ticket_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'note_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'ticket_activities_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'time_entries_test_helper.rb')
require 'faker'

class ActivityParserTest < ActionView::TestCase
  include Helpdesk::Activities
  include TicketHelper
  include TicketActivitiesTestHelper
  include NoteTestHelper
  include TimeEntriesTestHelper

  def setup
    @account = Account.first
    Account.stubs(:current).returns(@account)
    @user = @account.users.first
    User.stubs(:current).returns(@user)
    @ticket = create_ticket(requester_id: @user.id)
    @target_ticket = create_ticket(requester_id: @user.id)
    @rule = @account.account_va_rules.first
    @agent = @user
    @timesheet = create_time_entry(ticket_id: @ticket.id, agent_id: @user.id)
    @note = create_note(ticket_id: @ticket.id, created_at: @ticket.created_at, user_id: @user.id)
  end

  def construct_data_hash
    obj_hash = {}
    obj_hash[:status_name] = Helpdesk::TicketStatus.status_objects_from_cache(Account.current).map { |status| [status.status_id, Helpdesk::TicketStatus.translate_status_name(status, 'name')] }.to_h
    obj_hash[:tickets] = @account.tickets.select('display_id, subject').where(display_id: @ticket.display_id).collect { |x| [x.display_id, x.subject] }.to_h
    obj_hash[:users] = @account.users.where(id: [@user.id]).collect { |user| [user.id, user] }.to_h
    obj_hash[:rules] = @account.account_va_rules.select('id, name').where(id: [@rule.id]).collect { |x| [x.id, x.name] }.to_h
    obj_hash[:notes] = @account.notes.where(id: [@note.id]).collect { |note| [note.id, note] }.to_h
    obj_hash
  end

  def teardown
    Account.unstub(:current)
    User.unstub(:current)
    super
  end

  def test_activity_parser_ticket_activity
    activity = email_to_agent_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_activity_parser_json_for_new_ticket_creation
    activity = get_activity_data(summary: 0)
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :json)
    assert_not_nil activity_parser.get_json
    assert_not_nil activity_parser.safe_send(:activity_summary)
    assert_not_nil activity_parser.safe_send(:account)
  end

  def test_activity_parser_json_for_outbound_email
    activity = get_activity_data(summary: 1)
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :json)
    assert_not_nil activity_parser.get_json
  end

  def test_activity_json_for_outbound_email
    activity = get_activity_data(summary: 1)
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_activity_parser_test_json
    activity = add_note_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :test_json)
    assert_not_nil activity_parser.get_test_json
  end

  def test_property_update_activity
    activity = property_update_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_property_update_activity_with_null_properties
    content = "{\"test_custom_country\":[null,null],\"test_custom_state\":[null,\"Queensland\"],\"test_custom_city\":[null,\"Brisbane\"],\"test_custom_number\":[null,\"12\"],\"test_custom_decimal\":[null,\"8900.89\"],\"test_custom_text\":[null,\"*\"],\"test_custom_paragraph\":[null,\"*\"],\"unchecked\":[\"test_custom_checkbox\"],\"test_custom_dropdown\":[null,\"Armaggedon\"],\"test_custom_date\":[null,\"2016-09-09\"],\"ticket_type\":[null,null],\"source\":[\"*\",\"3.0\"],\"status\":[\"5.0\",\"Closed\"],\"group_id\":[null,null],\"responder_id\":[null,null],\"requester_id\":[null,\"#{@ticket.requester_id}.0\"],\"priority\":[null,\"4.0\"],\"subject\":[null,\"*\"],\"description\":[null,\"*\"],\"internal_group_id\":[null,null],\"internal_agent_id\":[null,null],\"product_id\":[null,null], \"due_by\":[null,\"10\"]}"
    activity = get_activity_data(content: content)
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_invalid_fields_activity
    activity = invalid_fields_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_add_note_activity
    activity = add_note_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :json)
    assert_not_nil activity_parser.get_json
  end

  def test_add_note_activity_with_failures
    activity = get_activity_data(summary: '36.0', members: "{\"user_ids\":[\"#{@ticket.requester_id}\",\"#{@ticket.responder_id}\"],\"rule_ids\":[],\"note_ids\":[\"#{@note.id}\"],\"status_ids\":[\"#{@ticket.status}\"],\"ticket_ids\":[]}", email_failures: "[{\"#{@note.to_emails.first}\":\"{rand(0..3)}\"}]", content: "{\"note\":{\"id\":\"#{@note.id}.0\"},\"add_comment\":\"Comment added\"}")
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_email_failures_note_activity
    activity = email_failures_note_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_email_failures_ticket_activity
    activity = email_failures_ticket_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_spam_ticket_activity
    activity = spam_ticket_activity(true)
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_unspam_ticket_activity
    activity = spam_ticket_activity(false)
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
    User.any_instance.stubs(:zero?).returns(true)
    assert_not_nil activity_parser.safe_send(:system_event?)
    assert_not_nil activity_parser.safe_send(:user_event?)
  end

  def test_delete_ticket_activity
    activity = delete_ticket_activity(true)
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_restore_ticket_activity
    activity = delete_ticket_activity(false)
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_archive_ticket_activity
    activity = archive_ticket_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_add_tag_activity
    activity = tag_activity(true)
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_remove_tag_activity
    activity = tag_activity(false)
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_watcher_activity
    activity = watcher_activity(true)
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_add_watcher_activity
    activity = get_activity_data(summary: '24.0', content: "{\"add_watcher\":[\"#{@user.id}\"]}")
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_remove_watcher_activity
    activity = watcher_activity(false)
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_execute_scenario_activity
    activity = execute_scenario_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_timesheet_create_activity
    activity = timesheet_create_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_timesheet_edit_activity
    activity = timesheet_edit_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_timesheet_delete_activity
    activity = timesheet_delete_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_timesheet_create_activity_with_timer_running
    activity = get_activity_data(summary: '26.0', content: "{\"timesheet_create\":{\"user_id\":[null,\"#{@user.id}.0\"],\"executed_at\":[null,\"1483036200.0\"],\"timesheet_id\":[null,\"#{@timesheet.id}.0\"],\"billable\":[null,true],\"time_spent\":[null,\"5400.0\"],\"timer_running\":[null, true]}}")
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_timesheet_create_activity_with_old_entry_timer_running
    activity = get_activity_data(summary: '26.0', content: "{\"timesheet_old\":{\"user_id\":[null,\"#{@user.id}.0\"],\"executed_at\":[null,\"1483036200.0\"],\"timesheet_id\":[null,\"#{@timesheet.id}.0\"],\"billable\":[null,true],\"time_spent\":[null,\"5400.0\"],\"timer_running\":[null, true]}}")
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_timesheet_create_activity_with_old_entry_timer_running_false
    activity = get_activity_data(summary: '26.0', content: "{\"timesheet_old\":{\"user_id\":[null,\"#{@user.id}.0\"],\"executed_at\":[null,\"1483036200.0\"],\"timesheet_id\":[null,\"#{@timesheet.id}.0\"],\"billable\":[null,true],\"time_spent\":[null,\"5400.0\"],\"timer_running\":[null, false]}}")
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_timesheet_create_activity_with_old_entry_timer_not_running
    activity = get_activity_data(summary: '26.0', content: "{\"timesheet_old\":{\"user_id\":[null,\"#{@user.id}.0\"],\"executed_at\":[null,\"1483036200.0\"],\"timesheet_id\":[null,\"#{@timesheet.id}.0\"],\"billable\":[null,true],\"time_spent\":[null,\"5400.0\"]}}")
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_timesheet_edit_activity_with_timer_running
    activity = get_activity_data(summary: '29.0', content: "{\"timesheet_edit\":{\"user_id\":[\"#{@user.id}.0\",\"#{@user.id}\"],\"executed_at\":[\"1483036200.0\",\"1483036260.0\"],\"timesheet_id\":[null,\"#{@timesheet.id}.0\"],\"billable\":[true,true],\"time_spent\":[\"5400.0\",\"5700.0\"],\"timer_running\":[false, true]}}")
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
    assert_not_nil activity_parser.safe_send(:get_performed_time, 1)
  end

  def test_add_cc_activity
    activity = add_cc_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :test_json)
    assert_not_nil activity_parser.get_test_json
  end

  def test_email_to_group_activity
    activity = email_to_group_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_email_to_agent_activity
    activity = email_to_agent_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_email_to_requester_activity
    activity = email_to_requester_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_ticket_merge_target_activityticket_merge_target_activity
    activity = ticket_merge_target_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_ticket_merge_source_activity
    activity = ticket_merge_source_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_ticket_split_target_activity
    activity = ticket_split_target_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_ticket_split_source_activity
    activity = ticket_split_source_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_ticket_import_activity
    activity = ticket_import_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_round_robin_activity
    activity = round_robin_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_delete_status_activity
    activity = delete_status_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_empty_action_activity
    activity = empty_action_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_skill_name_activity
    activity = skill_name_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_skill_name_activity_with_null_properties
    content = '{"skill_name": [null,null], "product_id": [null, "freshdesk"]}'
    activity = get_activity_data(content: content)
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_delete_group_activity
    activity = delete_group_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_remove_group_activity
    activity = remove_group_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_remove_agent_activity
    activity = remove_agent_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_remove_status_activity
    activity = remove_status_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_shared_ownership_reset_activity
    activity = shared_ownership_reset_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_delete_agent_activity
    activity = delete_agent_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_delete_internal_agent_activity
    activity = delete_internal_agent_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_delete_internal_group_activity
    activity = delete_internal_group_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_ticket_linked_activity
    activity = ticket_linked_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_ticket_unlinked_activity
    activity = ticket_unlinked_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_tracker_linked_activity
    activity = tracker_linked_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_tracker_unlinked_activity
    activity = tracker_unlinked_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_tracker_unlink_all_activity
    activity = get_activity_data(summary: '0.0', content: '{"tracker_unlink_all":"1"}')
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_tracker_reset_activity
    activity = tracker_reset_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_parent_ticket_linked_activity
    activity = parent_ticket_linked_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_parent_ticket_unlinked_activity
    activity = parent_ticket_unlinked_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_child_ticket_linked_activity
    activity = child_ticket_linked_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_child_ticket_unlinked_activity
    activity = child_ticket_unlinked_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_parent_ticket_reopened_activity
    activity = parent_ticket_reopened_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
    assert_not_nil activity_parser.safe_send(:ticket?)
  end

  def test_default_system_activity
    activity = default_system_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end

  def test_empty_user_activity
    activity = empty_user_activity
    activity_parser = Helpdesk::Activities::ActivityParser.new(activity.ticket_data[0], construct_data_hash, @ticket, :tkt_activity)
    assert_not_nil activity_parser.get_tkt_activity
  end
end
