module TicketActivitiesTestHelper
  class TestActivityData
    attr_accessor :ticket_data, :total_count, :query_count,
                  :members, :error_message
  end

  class TestTicketData
    attr_accessor :actor, :event_type, :published_time, :account_id,
                  :object, :object_id, :content, :summary, :email_type,
                  :recipient_list, :message_id, :kind, :email_failures
  end

  def property_update_activity
    content = "{\"test_custom_country\":[null,\"Australia\"],\"test_custom_state\":[null,\"Queensland\"],\"test_custom_city\":[null,\"Brisbane\"],\"test_custom_number\":[null,\"12\"],\"test_custom_decimal\":[null,\"8900.89\"],\"test_custom_text\":[null,\"*\"],\"test_custom_paragraph\":[null,\"*\"],\"unchecked\":[\"test_custom_checkbox\"],\"test_custom_dropdown\":[null,\"Armaggedon\"],\"test_custom_date\":[null,\"2016-09-09\"],\"ticket_type\":[null,\"Incident\"],\"source\":[\"*\",\"3.0\"],\"status\":[\"5.0\",\"Closed\"],\"group_id\":[null,\"Sales\"],\"responder_id\":[null,\"#{@ticket.responder_id}.0\"],\"requester_id\":[null,\"#{@ticket.requester_id}.0\"],\"priority\":[null,\"4.0\"],\"subject\":[null,\"*\"],\"description\":[null,\"*\"],\"internal_group_id\":[null,\"QA\"],\"internal_agent_id\":[null,\"#{@ticket.responder_id}.0\"]}"
    get_activity_data(content: content)
  end

  def invalid_fields_activity
    content = '{"invalid_field":[null, "TestValue"],"invalid_text":[null,"*"],"checked":["invalid_checkbox"]}'
    get_activity_data(content: content)
  end

  def add_note_activity
    params = {}
    params[:summary] = '36.0'
    params[:members] = "{\"user_ids\":[\"#{@ticket.requester_id}\",\"#{@ticket.responder_id}\"],\"rule_ids\":[],\"note_ids\":[\"#{@note.id}\"],\"status_ids\":[\"#{@ticket.status}\"],\"ticket_ids\":[]}"
    params[:content] = "{\"note\":{\"id\":\"#{@note.id}.0\"}}"
    get_activity_data(params)
  end

  def email_failures_note_activity
    params = {}
    params[:members] = "{\"user_ids\":[\"#{@ticket.requester_id}\",\"#{@ticket.responder_id}\"],\"rule_ids\":[],\"note_ids\":[\"#{@note.id}\"],\"status_ids\":[\"#{@ticket.status}\"],\"ticket_ids\":[]}"
    params[:email_failures] = "[{\"#{@note.to_emails.first}\":\"{rand(0..3)}\"}]"
    get_activity_data(params)
  end

   def email_failures_ticket_activity
    params = {}
    params[:members] = "{\"user_ids\":[\"#{@ticket.requester_id}\",\"#{@ticket.responder_id}\"],\"rule_ids\":[],\"status_ids\":[\"#{@ticket.status}\"],\"ticket_ids\":[]}"
    params[:email_failures] = "[{\"#{@ticket.requester.email}\":\"{rand(0..3)}\"}]" 
    get_activity_data(params)
  end

  def spam_ticket_activity(flag)
    params = {}
    params[:summary] = flag ? '3.0' : '5.0'
    params[:content] = flag ? '{"spam":["*",true]}' : '{"spam":["*",null]}'
    get_activity_data(params)
  end

  def delete_ticket_activity(flag)
    params = {}
    params[:summary] = flag ? '2.0' : '4.0'
    params[:content] = flag ? '{"deleted":["*",true]}' : '{"deleted":["*",null]}'
    get_activity_data(params)
  end

  def archive_ticket_activity
    params = {}
    params[:summary] = '35.0'
    params[:content] = '{"archive":["*",true]}'
    get_activity_data(params)
  end

  def tag_activity(flag)
    params = {}
    params[:summary] = flag ? '18.0' : '19.0'
    params[:content] = flag ? '{"add_tag":["update_tag1","update_tag2"]}' : '{"remove_tag":["update_tag1","update_tag2"]}'
    get_activity_data(params)
  end

  def watcher_activity(flag)
    params = {}
    params[:summary] = flag ? '24.0' : '25.0'
    params[:content] = flag ? "{\"watcher\":{\"user_id\":[null,\"#{@agent.id}.0\"]}}" : "{\"watcher\":{\"user_id\":[\"#{@ticket.requester_id}.0\", null]}}"
    get_activity_data(params)
  end

  def execute_scenario_activity
    params = {}
    params[:content] = '{"execute_scenario":["2.0","Mark as Feature Request"]}'
    get_activity_data(params)
  end

  def timesheet_create_activity
    params = {}
    params[:summary] = '26.0'
    params[:content] = "{\"timesheet_create\":{\"user_id\":[null,\"#{@agent.id}.0\"],\"executed_at\":[null,\"1483036200.0\"],\"timesheet_id\":[null,\"#{@timesheet.id}.0\"],\"billable\":[null,true],\"time_spent\":[null,\"5400.0\"]}}"
    get_activity_data(params)
  end

  def timesheet_edit_activity
    params = {}
    params[:summary] = '29.0'
    params[:content] = "{\"timesheet_edit\":{\"user_id\":[\"#{@agent.id}.0\",\"#{@agent.id}\"],\"executed_at\":[\"1483036200.0\",\"1483036260.0\"],\"timesheet_id\":[null,\"#{@timesheet.id}.0\"],\"billable\":[true,true],\"time_spent\":[\"5400.0\",\"5700.0\"]}}"
    get_activity_data(params)
  end

  def timesheet_delete_activity
    params = {}
    params[:summary] = '30.0'
    params[:content] = "{\"timesheet_delete\":{\"user_id\":[\"#{@agent.id}.0\",null],\"executed_at\":[\"1483036200.0\",null],\"timesheet_id\":[\"#{@timesheet.id}.0\",null],\"billable\":[true,null],\"time_spent\":[\"5700.0\",null]}}"
    get_activity_data(params)
  end

  def add_cc_activity
    params = {}
    params[:summary] = '40.0'
    params[:content] = "{\"system_changes\":{\"#{@rule.id}\":{\"rule\":[\"1.0\",\"Add CC\"],\"add_a_cc\":[\"test@cc.com\"]}}}"
    params[:event_type] = 'system'
    get_activity_data(params)
  end

  def email_to_group_activity
    params = {}
    params[:summary] = '40.0'
    params[:content] = "{\"system_changes\":{\"#{@rule.id}\":{\"rule\":[\"1.0\",\"Email test\"],\"email_to_group\":[\"Product Management\"]}}}"
    params[:event_type] = 'system'
    get_activity_data(params)
  end

  def email_to_agent_activity
    params = {}
    params[:summary] = '40.0'
    params[:content] = "{\"system_changes\":{\"#{@rule.id}\":{\"rule\":[\"1.0\",\"Email test\"],\"email_to_agent\":[\"#{@agent.id}.0\"]}}}"
    params[:event_type] = 'system'
    get_activity_data(params)
  end

  def email_to_requester_activity
    params = {}
    params[:summary] = '40.0'
    params[:content] = "{\"system_changes\":{\"#{@rule.id}\":{\"rule\":[\"1.0\",\"Email test\"],\"email_to_requester\":[\"#{@ticket.requester_id}.0\"]}}}"
    params[:event_type] = 'system'
    get_activity_data(params)
  end

  def ticket_merge_target_activity
    params = {}
    params[:summary] = '32.0'
    params[:content] = "{\"activity_type\":{\"target_ticket_id\":[\"#{@target_ticket.display_id}.0\"],\"source_ticket_id\":[\"#{@ticket.display_id}.0\"],\"type\":\"ticket_merge_target\"}}"
    get_activity_data(params)
  end

  def ticket_merge_source_activity
    params = {}
    params[:summary] = '31.0'
    params[:content] = "{\"activity_type\":{\"target_ticket_id\":[\"#{@target_ticket.display_id}.0\"],\"source_ticket_id\":[\"#{@ticket.display_id}.0\"],\"type\":\"ticket_merge_source\"}}"
    get_activity_data(params)
  end

  def ticket_split_target_activity
    params = {}
    params[:content] = "{\"activity_type\":{\"target_ticket_id\":[\"#{@target_ticket.display_id}.0\"],\"source_ticket_id\":[\"#{@ticket.display_id}.0\"],\"type\":\"ticket_split_target\"}}"
    get_activity_data(params)
  end

  def ticket_split_source_activity
    params = {}
    params[:summary] = '33.0'
    params[:content] = "{\"activity_type\":{\"target_ticket_id\":[\"#{@target_ticket.display_id}.0\"],\"source_ticket_id\":[\"#{@ticket.display_id}.0\"],\"type\":\"ticket_split_source\"}}"
    get_activity_data(params)
  end

  def ticket_import_activity
    params = {}
    params[:content] = '{"activity_type":{"imported_at":"1484212625.25809","type":"ticket_import"}}'
    get_activity_data(params)
  end

  def round_robin_activity
    params = {}
    params[:summary] = '37.0'
    params[:content] = "{\"activity_type\":{\"responder_id\":[null,\"#{@agent.id}.0\"],\"type\":\"round_robin\",\"skill_name\": [null,\"Test Skill\"]}}"
    params[:event_type] = 'system'
    get_activity_data(params)
  end

  def delete_status_activity
    params = {}
    params[:content] = '{"delete_status":["Open", "5.0"]}'
    get_activity_data(params)
  end

  def empty_action_activity
    params = {}
    params[:content] = '{"note":{}}'
    get_activity_data(params)
  end

  def skill_name_activity
    params = {}
    params[:content] = '{"skill_name": [null,"Test Skill"]}'
    get_activity_data(params)
  end

  def delete_group_activity
    params = {}
    params[:content] = '{"delete_group":["Product Management"]}'
    get_activity_data(params)
  end

  def remove_group_activity
    params = {}
    params[:content] = '{"remove_group":["Product Management", "Open"]}'
    get_activity_data(params)
  end

  def remove_agent_activity
    params = {}
    params[:content] = "{\"remove_agent\":[\"#{@agent.id}.0\", \"Product Management\"]}"
    get_activity_data(params)
  end

  def remove_status_activity
    params = {}
    params[:content] = '{"remove_status":["Open"]}'
    get_activity_data(params)
  end

  def shared_ownership_reset_activity
    params = {}
    params[:content] = "{\"shared_ownership_reset\":{\"internal_group_id\":[null,\"QA\"],\"internal_agent_id\":[null,\"#{@agent.id}.0\"]}}"
    get_activity_data(params)
  end

  def delete_agent_activity
    params = {}
    params[:content] = "{\"delete_agent\":[\"#{@agent.id}.0\"]}"
    get_activity_data(params)
  end

  def delete_internal_agent_activity
    params = {}
    params[:summary] = '40.0'
    params[:content] = "{\"delete_internal_agent\":[\"#{@agent.id}.0\"]}"
    get_activity_data(params)
  end

  def delete_internal_group_activity
    params = {}
    params[:summary] = '40.0'
    params[:content] = '{"delete_internal_group":["Backend Engineering"]}'
    get_activity_data(params)
  end

  def ticket_linked_activity
    params = {}
    params[:summary] = '41.0'
    params[:content] = '{"rel_tkt_link":["12457.0"]}'
    get_activity_data(params)
  end

  def ticket_unlinked_activity
    params = {}
    params[:summary] = '42.0'
    params[:content] = '{"rel_tkt_unlink":["12457.0"]}'
    get_activity_data(params)
  end

  def tracker_linked_activity
    params = {}
    params[:summary] = '0.0'
    params[:content] = '{"tracker_link":["12457.0"]}'
    get_activity_data(params)
  end

  def tracker_unlinked_activity
    params = {}
    params[:summary] = '0.0'
    params[:content] = '{"tracker_unlink":["12457.0"]}'
    get_activity_data(params)
  end

  def tracker_reset_activity
    params = {}
    params[:content] = '{"tracker_reset":[]}'
    get_activity_data(params)
  end

  def parent_ticket_linked_activity
    params = {}
    params[:content] = '{"assoc_parent_tkt_link":["12457.0"]}'
    get_activity_data(params)
  end

  def parent_ticket_unlinked_activity
    params = {}
    params[:content] = '{"assoc_parent_tkt_unlink":["12457.0"]}'
    get_activity_data(params)
  end

  def child_ticket_linked_activity
    params = {}
    params[:content] = '{"child_tkt_link":["12457.0"]}'
    get_activity_data(params)
  end

  def child_ticket_unlinked_activity
    params = {}
    params[:content] = '{"child_tkt_unlink":["12457.0"]}'
    get_activity_data(params)
  end

  def parent_ticket_reopened_activity
    params = {}
    params[:content] = '{"assoc_parent_tkt_open":["12457.0"]}'
    get_activity_data(params)
  end

  def default_system_activity
    params = {}
    params[:content] = '{"assoc_parent_tkt_open":["12457.0"]}'
    params[:event_type] = 'system'
    get_activity_data(params)
  end

  def empty_user_activity
    params = {}
    params[:content] = "{\"responder_id\":[null,\"#{@ticket.responder_id}.0\"]}"
    # invalid user_id
    params[:members] = '{"user_ids":["12345689.0"]}'
    get_activity_data(params)
  end

  def system_add_note_activity
    params = {}
    params[:content] = '{ "add_note": true }'
    params[:event_type] = 'system'
    get_activity_data(params)
  end

  def system_forward_ticket_activity
    params = {}
    params[:content] = '{ "forward_ticket": true }'
    params[:event_type] = 'system'
    get_activity_data(params)
  end

  # PATTERNS
  def property_update_activity_pattern(ticket_activity_data)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: :property_update,
                                                                content: {
                                                                  subject: '*',
                                                                  description: '*',
                                                                  ticket_type: 'Incident',
                                                                  source: 3,
                                                                  status: 5,
                                                                  status_label: 'Closed',
                                                                  group_name: 'Sales',
                                                                  responder_id: @ticket.responder_id,
                                                                  requester_id: @ticket.requester_id,
                                                                  priority: 4,
                                                                  internal_group_name: 'QA',
                                                                  internal_agent_id: @ticket.responder_id,
                                                                  custom_fields: {
                                                                    test_custom_country: 'Australia',
                                                                    test_custom_state: 'Queensland',
                                                                    test_custom_city: 'Brisbane',
                                                                    test_custom_number: '12',
                                                                    test_custom_decimal: '8900.89',
                                                                    test_custom_text: '*',
                                                                    test_custom_paragraph: '*',
                                                                    test_custom_checkbox: false,
                                                                    test_custom_dropdown: 'Armaggedon',
                                                                    test_custom_date: '2016-09-09'
                                                                  }
                                                                }
                                                              }
                                                            ])
    end
    result
  end

  def invalid_fields_activity_pattern(ticket_activity_data)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: :property_update,
                                                                content: {
                                                                  invalid_fields: [
                                                                    {
                                                                      field_name: 'invalid_field',
                                                                      value: 'TestValue'
                                                                    },
                                                                    {

                                                                      field_name: 'invalid_text',
                                                                      value: '*'
                                                                    },
                                                                    {
                                                                      field_name: 'invalid_checkbox',
                                                                      value: true
                                                                    }
                                                                  ]
                                                                }
                                                              }
                                                            ])
    end
    result
  end

  def note_activity_pattern(ticket_activity_data)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: :note,
                                                                content: private_note_pattern({}, @note)
                                                              }
                                                            ])
    end
    result
  end

  def tag_activity_pattern(ticket_activity_data, flag)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      # Could not find why tkt_data.class is ActivityDecorator
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: flag ? :add_tag : :remove_tag,
                                                                content: content[(flag ? :add_tag : :remove_tag)]
                                                              }
                                                            ])
    end
    result
  end

  def spam_activity_pattern(ticket_activity_data)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: content[:spam][1] ? :spam : :unspam
                                                              }
                                                            ])
    end
    result
  end

  def delete_activity_pattern(ticket_activity_data)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: content[:deleted][1] ? :delete : :restore
                                                              }
                                                            ])
    end
    result
  end

  def archive_activity_pattern(ticket_activity_data)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: :archive
                                                              }
                                                            ])
    end
    result
  end

  def watcher_activity_pattern(ticket_activity_data)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      content_hash = content[:watcher][:user_id]
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: :add_watcher,
                                                                content: {
                                                                  add_watcher: (content_hash[1].to_i.zero? ? false : true),
                                                                  user_ids: [(content_hash[1].to_i.zero? ? content_hash[0].to_i : content_hash[1].to_i)]
                                                                }
                                                              }
                                                            ])
    end
    result
  end

  def execute_scenario_activity_pattern(ticket_activity_data)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: :execute_scenario,
                                                                content: {
                                                                  name: content[:execute_scenario][1]
                                                                }
                                                              }
                                                            ])
    end
    result
  end

  def create_timesheet_activity_pattern(ticket_activity_data)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      content_hash = content[:timesheet_create]
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: :timesheet_create,
                                                                content: {
                                                                  user_id: content_hash[:user_id][1].to_i,
                                                                  executed_at: Time.at(content_hash[:executed_at][1].to_i).utc,
                                                                  billable: content_hash[:billable][1],
                                                                  time_spent: content_hash[:time_spent][1].to_i
                                                                }
                                                              }
                                                            ])
    end
    result
  end

  def edit_timesheet_activity_pattern(ticket_activity_data)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      content_hash = content[:timesheet_edit]
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: :timesheet_edit,
                                                                content: {
                                                                  old_values: {
                                                                    user_id: content_hash[:user_id][0].to_i,
                                                                    executed_at: Time.at(content_hash[:executed_at][0].to_i).utc,
                                                                    billable: content_hash[:billable][0],
                                                                    time_spent: content_hash[:time_spent][0].to_i
                                                                  },
                                                                  new_values: {
                                                                    user_id: content_hash[:user_id][1].to_i,
                                                                    executed_at: Time.at(content_hash[:executed_at][1].to_i).utc,
                                                                    billable: content_hash[:billable][1],
                                                                    time_spent: content_hash[:time_spent][1].to_i
                                                                  }
                                                                }
                                                              }
                                                            ])
    end
    result
  end

  def delete_timesheet_activity_pattern(ticket_activity_data)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      content_hash = content[:timesheet_delete]
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: :timesheet_delete,
                                                                content: {
                                                                  user_id: content_hash[:user_id][0].to_i,
                                                                  executed_at: Time.at(content_hash[:executed_at][0].to_i).utc,
                                                                  billable: content_hash[:billable][0],
                                                                  time_spent: content_hash[:time_spent][0].to_i
                                                                }
                                                              }
                                                            ])
    end
    result
  end

  def add_cc_activity_pattern(ticket_activity_data)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      content_hash = content[:system_changes][:"#{@rule.id}"]
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: :add_a_cc,
                                                                content: content_hash[:add_a_cc]
                                                              }
                                                            ])
    end
    result
  end

  def email_to_activity_pattern(ticket_activity_data, type)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      content_hash = content[:system_changes][:"#{@rule.id}"]
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: type,
                                                                content: content_hash[type].compact.map do |value|
                                                                  value.to_i == 0 ? value : value.to_i
                                                                end
                                                              }
                                                            ])
    end
    result
  end

  def ticket_merge_activity_pattern(ticket_activity_data, type)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      content_hash = (type == :ticket_merge_source) ? { target_ticket_id: content[:activity_type][:target_ticket_id][0].to_i } : { source_ticket_ids: content[:activity_type][:source_ticket_id].map(&:to_i) }
      ticket = (type == :ticket_merge_source) ? @ticket : @target_ticket
      result << result_common_hash(tkt_data, content, ticket).merge(actions: [
                                                                      {
                                                                        type: type,
                                                                        content: content_hash
                                                                      }
                                                                    ])
    end
    result
  end

  def ticket_split_activity_pattern(ticket_activity_data, type)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      content_hash = (type == :ticket_split_source) ? { target_ticket_id: content[:activity_type][:target_ticket_id][0].to_i } : { source_ticket_id: content[:activity_type][:source_ticket_id][0].to_i }
      ticket = (type == :ticket_split_source) ? @ticket : @target_ticket
      result << result_common_hash(tkt_data, content, ticket).merge(actions: [
                                                                      {
                                                                        type: type,
                                                                        content: content_hash
                                                                      }
                                                                    ])
    end
    result
  end

  def ticket_import_activity_pattern(ticket_activity_data)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      content_hash = { imported_at: Time.at(content[:activity_type][:imported_at].to_i).utc }
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: :ticket_import,
                                                                content: content_hash
                                                              }
                                                            ])
    end
    result
  end

  def round_robin_activity_pattern(ticket_activity_data)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      content_hash = { responder_id: content[:activity_type][:responder_id][1].to_i, skill_name: content[:activity_type][:skill_name][1] }
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: :round_robin,
                                                                content: content_hash
                                                              }
                                                            ])
    end
    result
  end

  def delete_status_activity_pattern(ticket_activity_data)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      content_hash = content[:delete_status]
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: :delete_status,
                                                                content: { deleted_value: content_hash[0], current_value: content_hash[1].to_i }
                                                              }
                                                            ])
    end
    result
  end

  def skill_name_activity_pattern(ticket_activity_data)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      content_hash = content[:skill_name]
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: :skill_name,
                                                                content: content_hash[1]
                                                              }
                                                            ])
    end
    result
  end

  def delete_group_activity_pattern(ticket_activity_data)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      content_hash = content[:delete_group]
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: :delete_group,
                                                                content: { deleted_value: content_hash[0] }
                                                              }
                                                            ])
    end
    result
  end

  def remove_group_activity_pattern(ticket_activity_data)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      content_hash = content[:remove_group]
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: :remove_group,
                                                                content: { group_name: content_hash[0], status_name: content_hash[1] }
                                                              }
                                                            ])
    end
    result
  end

  def remove_agent_activity_pattern(ticket_activity_data)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      content_hash = content[:remove_agent]
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: :remove_agent,
                                                                content: { user_id: content_hash[0].to_i, group_name: content_hash[1] }
                                                              }
                                                            ])
    end
    result
  end

  def remove_status_activity_pattern(ticket_activity_data)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      content_hash = content[:remove_status]
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: :remove_status,
                                                                content: content_hash[0]
                                                              }
                                                            ])
    end
    result
  end

  def shared_ownership_reset_activity_pattern(ticket_activity_data)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      content_hash = content[:shared_ownership_reset]
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: :shared_ownership_reset,
                                                                content: { internal_group_name: content_hash[:internal_group_id][1], internal_agent_id: content_hash[:internal_agent_id][1].to_i }
                                                              }
                                                            ])
    end
    result
  end

  def delete_agent_activity_pattern(ticket_activity_data)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      content_hash = content[:delete_agent]
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: :delete_agent,
                                                                content: content_hash[0].to_i
                                                              }
                                                            ])
    end
    result
  end

  def delete_internal_agent_activity_pattern(ticket_activity_data)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      content_hash = content[:delete_internal_agent]
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: :delete_internal_agent,
                                                                content: content_hash[0].to_i
                                                              }
                                                            ])
    end
    result
  end

  def delete_internal_group_activity_pattern(ticket_activity_data)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      content_hash = content[:delete_internal_group]
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: :delete_internal_group,
                                                                content: content_hash[0]
                                                              }
                                                            ])
    end
    result
  end

  def ticket_linked_activity_pattern(ticket_activity_data)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      content_hash = content[:rel_tkt_link]
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: :ticket_linked,
                                                                content: content_hash[0].to_i
                                                              }
                                                            ])
    end
    result
  end

  def ticket_unlinked_activity_pattern(ticket_activity_data)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      content_hash = content[:rel_tkt_unlink]
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: :ticket_unlinked,
                                                                content: content_hash[0].to_i
                                                              }
                                                            ])
    end
    result
  end

  def tracker_linked_activity_pattern(ticket_activity_data)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      content_hash = content[:tracker_link]
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: :tracker_linked,
                                                                content: content_hash.map(&:to_i)
                                                              }
                                                            ])
    end
    result
  end

  def tracker_unlinked_activity_pattern(ticket_activity_data)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      content_hash = content[:tracker_unlink]
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: :tracker_unlinked,
                                                                content: content_hash.map(&:to_i)
                                                              }
                                                            ])
    end
    result
  end

  def tracker_reset_activity_pattern(ticket_activity_data)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: :tracker_reset
                                                              }
                                                            ])
    end
    result
  end

  def child_ticket_linked_activity_pattern(ticket_activity_data)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      content_hash = content[:child_tkt_link]
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: :child_ticket_linked,
                                                                content: content_hash[0].to_i
                                                              }
                                                            ])
    end
    result
  end

  def child_ticket_unlinked_activity_pattern(ticket_activity_data)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      content_hash = content[:child_tkt_unlink]
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: :child_ticket_unlinked,
                                                                content: content_hash[0].to_i
                                                              }
                                                            ])
    end
    result
  end

  def parent_ticket_linked_activity_pattern(ticket_activity_data)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      content_hash = content[:assoc_parent_tkt_link]
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: :parent_ticket_linked,
                                                                content: content_hash[0].to_i
                                                              }
                                                            ])
    end
    result
  end

  def parent_ticket_unlinked_activity_pattern(ticket_activity_data)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      content_hash = content[:assoc_parent_tkt_unlink]
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: :parent_ticket_unlinked,
                                                                content: content_hash.map(&:to_i)
                                                              }
                                                            ])
    end
    result
  end

  def parent_ticket_reopened_activity_pattern(ticket_activity_data)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: :parent_ticket_reopened
                                                              }
                                                            ])
    end
    result
  end

  def default_system_activity_pattern(ticket_activity_data)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: :parent_ticket_reopened
                                                              }
                                                            ])
    end
    result
  end

  def system_add_note_activity_pattern(ticket_activity_data)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: :add_note,
                                                                content: { add_note: true }
                                                              }
                                                            ])
    end
    result
  end

  def system_forward_ticket_activity_pattern(ticket_activity_data)
    result = []
    ticket_activity_data.ticket_data.each do |tkt_data|
      content = JSON.parse(tkt_data.record.content).deep_symbolize_keys
      performer_type = tkt_data.event_type.to_sym
      result << result_common_hash(tkt_data, content).merge(actions: [
                                                              {
                                                                type: :forward_ticket,
                                                                content: { forward_ticket: true }
                                                              }
                                                            ])
    end
    result
  end

  # HELPERS
  def get_activity_data(params = {})
    activity_data = TestActivityData.new
    activity_data.total_count   = params[:total_count] || 1
    activity_data.query_count   = params[:total_count] || 1
    activity_data.members       = params[:members] || "{\"user_ids\":[\"#{@ticket.requester_id}\",\"#{@ticket.responder_id}\"],\"rule_ids\":[\"#{@rule.id}\"],\"note_ids\":[],\"status_ids\":[\"#{@ticket.status}\"],\"ticket_ids\":[]}"
    activity_data.error_message = params[:error_message] || {}
    ticket_data                 = TestTicketData.new
    ticket_data.actor           = params[:actor] || @ticket.requester_id
    ticket_data.event_type      = params[:event_type] || 'user'
    ticket_data.published_time  = 1
    ticket_data.account_id      = @ticket.account_id
    ticket_data.object          = 'ticket'
    ticket_data.object_id       = "#{@ticket.display_id}.0"
    ticket_data.summary         = params[:summary] || '0.0'
    ticket_data.kind            = 0
    ticket_data.email_failures  = params[:email_failures] || 'null'
    # Hard coded the content for now
    ticket_data.content         = params[:content] || "{\"test_custom_country\":[null,\"USA\"],\"test_custom_state\":[null,\"California\"],\"test_custom_city\":[null,\"Burlingame\"],\"test_custom_number\":[null,\"32_234\"],\"test_custom_decimal\":[null,\"90.89\"],\"test_custom_text\":[null,\"*\"],\"test_custom_paragraph\":[null,\"*\"],\"checked\":[\"test_custom_checkbox\"],\"test_custom_dropdown\":[null,\"Pursuit of Happiness\"],\"test_custom_date\":[null,\"2015-09-09\"],\"add_tag\":[\"create_tag1\",\"create_tag2\"],\"ticket_type\":[null,\"Problem\"],\"source\":[\"*\",\"2.0\"],\"status\":[\"3.0\",\"Pending\"],\"group_id\":[null,\"Product Management\"],\"responder_id\":[null,\"#{@ticket.responder_id}.0\"],\"requester_id\":[null,\"#{@ticket.requester_id}.0\"],\"priority\":[null,\"2.0\"]}"
    activity_data.ticket_data   = [ticket_data]
    activity_data
  end

  def result_common_hash(tkt_data, content, ticket = @ticket)
    {
      id: tkt_data.published_time,
      ticket_id: ticket.display_id,
      performer: get_performer_hash(tkt_data, content, ticket),
      highlight: tkt_data.summary.nil? ? nil : tkt_data.summary.to_i,
      performed_at: Time.at(tkt_data.published_time / 10_000).utc
    }
  end

  def get_performer_hash(tkt_data, content, ticket)
    performer_type = tkt_data.event_type.to_sym
    performer_content = if performer_type == :user
                          user = get_user(tkt_data.actor)
                          user_hash = { user_id: user.id }
                          contact_hash = if User.current.privilege?(:view_contacts)
                                           private_api_contact_pattern({}, true, true, user)
                                         else
                                           {
                                             id: user.id,
                                             name: user.name,
                                             avatar: Hash
                                           }
                                         end
                          user_hash[:user] = contact_hash unless user.agent? || ticket.requester_id == user.id
                          user_hash
                        elsif content[:system_changes].present?
                          value = content[:system_changes]
                          rule = get_rule(value.keys.first.to_s.to_i)
                          {
                            id: value.keys.first.to_s.to_i,
                            type: ActivityConstants::RULE_LIST[value.values.first[:rule].first.to_i],
                            name: value.values.first[:rule].last,
                            exists: rule.present?
                          }
                        elsif content[:activity_type] && content[:activity_type][:type] == 'round_robin'
                          {
                            id: 0,
                            type: ActivityConstants::RULE_LIST[-1],
                            name: '',
                            exists: true
                          }
                        else
                          {
                            id: 0,
                            type: 'default_system',
                            name: '',
                            exists: true
                          }
                        end

    result = {
      type: performer_type
    }
    if performer_type == :user
      result[:user_id] = performer_content[:user_id]
      result[:user] = performer_content[:user] if performer_content[:user].present?
    else
      result[:system] = performer_content
    end
    result
  end

  def get_user(user_id)
    @account.all_users.find_by_id(user_id)
  end

  def get_rule(rule_id)
    @account.account_va_rules.find_by_id(rule_id)
  end

  def create_timesheet
    time_sheet = FactoryGirl.build(:time_sheet, user_id: @agent.id, workable_id: @ticket.id, account_id: @account.id, billable: 1, note: '')
    time_sheet.save
    time_sheet
  end
end
