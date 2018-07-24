module Va
  module Constants
    
    OPERATOR_TYPES = {
      :email       => [ "is", "is_not", "contains", "does_not_contain" ],
      :text        => [ "is", "is_not", "contains", "does_not_contain", "starts_with", "ends_with" ],
      :checkbox    => [ "selected", "not_selected" ],
      :choicelist  => [ "in", "not_in" ],
      :number      => [ "is", "is_not", "greater_than", "less_than" ],
      :decimal     => [ "is", "is_not", "greater_than", "less_than" ],
      :hours       => [ "is", "greater_than", "less_than" ],
      :nestedlist  => [ "is" ],
      :greater     => [ "greater_than" ],
      :object_id   => [ "in", "not_in"],
      :date_time   => [ "during" ],
      :date        => [ "is" , "is_not", "greater_than", "less_than" ],
      :object_id_array  => [ "in", "and", "not_in" ]
    }

    CF_OPERATOR_TYPES = {
      "custom_dropdown" => "choicelist",
      "custom_checkbox" => "checkbox",
      "custom_number"   => "number",
      "custom_decimal"  => "decimal",
      "nested_field"    => "nestedlist",
      "custom_date"     => "date"
    }

    CF_CUSTOMER_TYPES = {
      "custom_dropdown"     => "choicelist",
      "custom_checkbox"     => "checkbox",
      "custom_number"       => "number",
      "custom_url"          => "text",
      "custom_phone_number" => "text",
      "custom_paragraph"    => "text",
      "custom_date"         => "date"
    }

    OVERRIDE_OPERATOR_LABEL = {
      :in => 'is',
      :not_in => 'is_not'
    }.freeze

    OPERATOR_LIST =  [
      :is,
      :is_not,
      :contains,
      :does_not_contain,
      :starts_with,
      :ends_with,
      :between,
      :between_range,
      :selected,
      :not_selected,
      :less_than,
      :greater_than,
      :during,
      :in,
      :not_in,
      :and
    ].map { |i| [i, OVERRIDE_OPERATOR_LABEL[i] || i.to_s] }.freeze

    ALTERNATE_LABEL = [
        [ :in, 'admin.va_rules.label.object_id_array_in' ],
        [ :and, 'admin.va_rules.label.object_id_array_and' ],
        [ :not_in, 'admin.va_rules.label.object_id_array_not_in' ]
    ]

    NOT_OPERATORS = ['is_not', 'does_not_contain', 'not_selected', 'not_in']
    
    AUTOMATIONS_MAIL_NAME = "automations rule"

    AVAILABLE_LOCALES = I18n.available_locales_with_name.map{ |a| a.reverse }

    AVAILABLE_TIMEZONES = ActiveSupport::TimeZone.all.map { |time_zone| [time_zone.name.to_sym, time_zone.to_s] }

    MAX_CUSTOM_HEADERS = 5

    QUERY_OPERATOR = {
        :is => 'IS', :is_not => 'IS NOT', :in => 'IN',
        :not_in => 'NOT IN', :equal => '=', :not_equal => '!=',
        :greater_than => '>', :less_than => '<',
        :greater_than_equal_to => '>=', :less_than_equal_to => '<=',
        :not_equal_to => '<>', :like => 'LIKE', :not => 'NOT', :or => 'OR',
        :AND => 'AND'
    }

    NULL_QUERY = "%{db_column} IS NULL"

    NOT_NULL_QUERY = "%{db_column} IS NOT NULL"

    ANY_VALUE = {
        :with_none => "--",
        :without_none => "##"
    }

    NOTE_TYPES = {
      "--" => "Any",
      "public" => "Public",
      "private" => "Private"
    }

    TICKET_ACTIONS = {
      "update" => "updated",
      "delete" => "deleted",
      "marked_spam" => "marked as spam"
    }

    TIME_SHEET_ACTIONS = {
      "added" => "added", 
      "updated" => "updated"
    }

    READABLE_CONDITIONS = { 
      "from_email" => ["Requester Email"],
      "to_email" => ["To Email"],
      "ticlet_cc" => ["Ticket CC"],
      "subject" => ["Subject"],
      "description" => ["Description"],
      "subject_or_description" => ["Subject or Description"],
      "last_interaction" => ["Last Interaction"],
      "priority" => ["Priority", TicketConstants::PRIORITY_NAMES_BY_STR],
      "ticket_type" => ["Type"],
      "status" => ["Status", "ticket_statuses", "status_id"],
      "source" => ["Source", TicketConstants.readable_source_names_by_key],
      "product_id" => ["Product", "products", "id"],
      "created_at" => ["Created", VAConfig::CREATED_DURING_NAMES_BY_KEY],
      "responder_id" => ["Agent", "technicians", "id"],
      "group_id" => ["Group", "groups", "id"],
      "internal_agent_id" => ["Internal Agent", "technicians", "id"],
      "internal_group_id" => ["Internal Group", "groups", "id"],
      "tag_ids" => ["Tag", "tags", "id"],
      "requester_email" => ["Requester Email"],
      "requester_name" =>  ["Requester Name"],
      "requester_job_title" => ["Requester Title"],
      "requester_time_zone" => ["Requester Timezone"],
      "requester_language" => ["Requester Language"],
      "company_name" => ["Company Name"],
      "company_domains" => ["Company Domain"],
      "created_at_supervisor" => ["Hours since created"],
      "pending_since" => ["Hours since pending"],
      "resolved_at" => ["Hours since resolved"],
      "closed_at" => ["Hours since closed"],
      "opened_at" => ["Hours since reopened"],
      "first_assigned_at" => ["Hours since first assigned"],
      "assigned_at" => ["Hours since assigned"],
      "requester_responded_at" => ["Hours since requester responded"],
      "agent_responded_at" => ["Hours since agent responded"],
      "frDueBy" => ["Hours since first response due"],
      "due_by" => ["Hours since ticket overdue"]
    }

    READABLE_EVENTS = {
      "priority" => ["Priority is changed", TicketConstants::PRIORITY_NAMES_BY_STR],
      "ticket_type" => ["Type is changed"],
      "status" => ["Status is changed", "ticket_statuses", "status_id"],
      "group_id" => ["Group is updated", "groups", "id"],
      "responder_id" => ["Agent is updated", "technicians", "id"],
      "note_type" => ["Note is added", NOTE_TYPES],
      "reply_sent" => ["Reply is sent"],
      "due_by" => ["Due date is changed"],
      "ticket_action" => ["Ticket is", TICKET_ACTIONS],
      "time_sheet_action" => ["Time Entry is", TIME_SHEET_ACTIONS],
      "customer_feedback" => ["Customer Feedback is received", "active_custom_survey_choices", "face_value"],
      "mail_del_failed_requester" => ["Mail sent to requester address failed"],
      "mail_del_failed_others" => ["Mail sent to cc or forward address failed"]
    }

    READABLE_ACTIONS = {
      "priority" => ["Set Priority as", TicketConstants::PRIORITY_NAMES_BY_STR],
      "ticket_type" => ["Set Type as"],
      "status" => ["Set Status as", "ticket_statuses", "status_id"],
      "add_comment" => ["Add Note"],
      "add_tag" => ["Add Tag"],
      "add_a_cc" => ["Add a CC"],
      "add_watcher" => ["Add Watcher", "technicians", "id"],
      "trigger_webhook" => ["Trigger Webhook"],
      "responder_id" => ["Assign to Agent", "technicians", "id"],
      "group_id" => ["Assign to Group", "groups", "id"],
      "product_id" => ["Assign Product", "products", "id"],
      "send_email_to_group" => ["Send Email to Group"],
      "send_email_to_agent" => ["Send Email to Agent"],
      "send_email_to_requester" => ["Send Email to Requester"],
      "delete_ticket" => ["Delete the Ticket"],
      "mark_as_spam" => ["Mark as Spam"],
      "skip_notification" => ["Skip New Ticket Email Notifications"],
      "internal_group_id" => ["Assign to Internal Group", "groups", "id"],
      "internal_agent_id" => ["Assign to Internal Agent", "technicians", "id"]
    }

    def va_alternate_label
      va_alternate_label = {
        :object_id_array => Hash[*ALTERNATE_LABEL.map { |i, j| [i, I18n.t(j)] }.flatten]
      }
    end

    def va_operator_list
      Hash[*OPERATOR_LIST.map { |i, j| [i, I18n.t(j)] }.flatten]
    end
  end
end
