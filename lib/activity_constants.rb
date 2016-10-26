module ActivityConstants

  # NOTE: For any Activity list in this file, 
  # add new entries only at the end of the list and not in the middle/start
  # Ticket Activities
  TICKET_LIST = [
                  :new_ticket, :outbound_email, :deleted, :spam, :restored,
                  :undo_spam, :status, :responder_id, :reassign, :assigned_to_nobody,
                  :priority, :group_id, :group_change_none, :product_id,
                  :product_change_none, :source, :ticket_type, :ticket_type_none,
                  :add_tag, :remove_tag, :execute_scenario, :requester_id,
                  :change_dueby, :edit_ticket, :add_watcher, :remove_watcher,
                  :timesheet_new, :timer_started, :timer_stopped, :timesheet_edit,
                  :timesheet_delete, :ticket_merge_source, :ticket_merge_target,
                  :ticket_split_source, :ticket_split_target, :archive,
                  :conversation, :round_robin, :ticket_import, :system_changes,
                  :other_update, :rel_tkt_link, :rel_tkt_unlink
                ]

  TICKET_ACTIVITY_KEYS_BY_TOKEN = Hash[*TICKET_LIST.each_with_index.map { |key, index| [key, index] }.flatten]
  TICKET_ACTIVITY_TOKEN_BY_KEY  = Hash[*TICKET_LIST.each_with_index.map { |key, index| [index, key] }.flatten]

  # Note activities type
  NOTE_TYPE = [:note_create, :note_edit, :note_delete]
  
  NOTE_TYPE_KEYS_BY_TOKEN = Hash[*NOTE_TYPE.each_with_index.map { |key, index| [key, index] }.flatten]
  NOTE_TYPE_TOKEN_BY_KEY  = Hash[*NOTE_TYPE.each_with_index.map { |key, index| [index, key] }.flatten]

  # Forum category Activities
  FORUM_CATEGORY_LIST = [:new_forum_category, :delete_forum_category]

  FORUM_CATEGORY_ACTIVITY_KEYS_BY_TOKEN = Hash[*FORUM_CATEGORY_LIST.each_with_index.map { |key, index| [key, index] }.flatten]
  FORUM_CATEGORY_ACTIVITY_TOKEN_BY_KEY  = Hash[*FORUM_CATEGORY_LIST.each_with_index.map { |key, index| [index, key] }.flatten]

  # Forum Activities
  FORUM_LIST = [:new_forum, :delete_forum]
  
  FORUM_ACTIVITY_KEYS_BY_TOKEN = Hash[*FORUM_LIST.each_with_index.map { |key, index| [key, index] }.flatten]
  FORUM_ACTIVITY_TOKEN_BY_KEY  = Hash[*FORUM_LIST.each_with_index.map { |key, index| [index, key] }.flatten]

  # Topic Activities
  TOPIC_LIST =  [
                  :new_topic, :delete_topic, :stamp_none, :stamp_planned, 
                  :stamp_implemented, :stamp_not_taken, :stamp_in_progress, :stamp_deferred, 
                  :stamp_answered, :stamp_unanswered, :stamp_solved, :stamp_unsolved, 
                  :topic_merge
                ]

  TOPIC_ACTIVITY_KEYS_BY_TOKEN = Hash[*TOPIC_LIST.each_with_index.map { |key, index| [key, index] }.flatten]
  TOPIC_ACTIVITY_TOKEN_BY_KEY  = Hash[*TOPIC_LIST.each_with_index.map { |key, index| [index, key] }.flatten]

  # Post Activities
  POST_LIST = [:new_post, :delete_post]
  
  POST_ACTIVITY_KEYS_BY_TOKEN = Hash[*POST_LIST.each_with_index.map { |key, index| [key, index] }.flatten]
  POST_ACTIVITY_TOKEN_BY_KEY  = Hash[*POST_LIST.each_with_index.map { |key, index| [index, key] }.flatten]

  # Article Activities
  ARTICLE_LIST =  [:new_article, :delete_article]

  ARTICLE_ACTIVITY_KEYS_BY_TOKEN = Hash[*ARTICLE_LIST.each_with_index.map { |key, index| [key, index] }.flatten]
  ARTICLE_ACTIVITY_TOKEN_BY_KEY  = Hash[*ARTICLE_LIST.each_with_index.map { |key, index| [index, key] }.flatten]
  
  EVENT_MAP = [:sent, :processed, :delivered, :dropped, :deferred, :bounce]

  # Summary Tag for UI
  # For new summary tag, the below list should be updated  
  SUMMARY_MAP = {
                    :status => "status_change", :responder_id => "assigned", :reassign => "reassigned",
                    :assigned_to_nobody => "assigned_to_nobody", :priority => "priority_change", 
                    :group_id => "group_change", :group_change_none => "group_change_none", 
                    :product_id => "product_change", :product_change_none => "product_change_none", 
                    :source => "source_change", :ticket_type => "ticket_type_change",
                    :change_dueby => "due_date_updated", :timesheet_new => "timesheet.new", 
                    :timer_started => "timesheet.timer_started", :timer_stopped => "timesheet.timer_stopped",
                    :ticket_merge_target => "ticket_merge", :ticket_split_source => "ticket_split", 
                    :deleted => "deleted", :restored => "restored", :add_tag => "tag_change",
                    :remove_tag => "tag_change", :add_watcher => "add_watcher", 
                    :remove_watcher => "remove_watcher", :timesheet_edit => "timesheet.edit",
                    :timesheet_delete => "timesheet.delete", :execute_scenario => "execute_scenario",
                    :spam => "spam", :undo_spam => "restored", :round_robin => "assigned",
                    :rel_tkt_link => "rel_tkt_link", :rel_tkt_unlink => "rel_tkt_unlink"
                  }
                  
  # UI string map for token
  SUMMARY_FOR_TOKEN = {}
  SUMMARY_MAP.each do |k,v|
    SUMMARY_FOR_TOKEN.merge!({TICKET_ACTIVITY_KEYS_BY_TOKEN[k] => v})
  end
    
  TIME_MULTIPLIER = 10000

  # Limits
  QUERY_MAX_LIMIT = 200
  QUERY_UI_LIMIT  = 20
  
  #Comparators
  EQUAL_TO        = 'EQ'
  GREATER_THAN    = 'GT'
  GREATER_THAN_EQ = 'GE'
  LESS_THAN       = 'LT'
  LESS_THAN_EQ    = 'LE'

  # Va rules
  BUSINESS_RULE               = 1
  SCENARIO_AUTOMATION         = 2
  SUPERVISOR_RULE             = 3
  OBSERVER_RULE               = 4
  APP_BUSINESS_RULE           = 11
  INSTALLED_APP_BUSINESS_RULE = 12
  API_WEBHOOK_RULE            = 13

  RULE_LIST = { 
                1  => "business",
                2  => "scenario",
                3  => "supervisor",
                4  => "observer",
                11 => "app_business",
                12 => "installed_app",
                13 => "api_webhook"
              }
  DONT_CARE_VALUE = "*"

end