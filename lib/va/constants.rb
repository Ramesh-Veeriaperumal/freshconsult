module Va
  module Constants
    # va_rule execution count key expiry
    RULE_EXEC_COUNT_EXPIRY_DURATION = 604800 # 7 days

    DEFAULT_FIELD_HANDLER = {
        created_at: :date_time
    }.freeze
    
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
      object_id_array: ['in', 'and', 'not_in'],
      data_time_status: ['during']
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

    READABLE_LANGUAGE_NAMES_BY_KEY = AVAILABLE_LOCALES.to_h.stringify_keys

    AVAILABLE_TIMEZONES = ActiveSupport::TimeZone.all.map { |time_zone| [time_zone.name.to_sym, time_zone.to_s] }

    MAX_CUSTOM_HEADERS = 5

    MAX_ACTION_DATA_LIMIT = 63000

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

    WEBHOOK_REQUEST_TYPES = {
      '1' => 'GET',
      '2' => 'POST',
      '3' => 'PUT',
      '4' => 'PATCH',
      '5' => 'DELETE'
    }

    WEBHOOK_REQUEST_TYPES_ID = WEBHOOK_REQUEST_TYPES.invert

    WEBHOOK_CONTENT_TYPES = {
      '1' => 'XML',
      '2' => 'JSON',
      '3' => 'X-FORM-URLENCODED'
    }

    WEBHOOK_CONTENT_TYPES_ID = WEBHOOK_CONTENT_TYPES.invert

    LAZY_EVALUATIONS = {
      'User'             => [:segments],
      'Company'          => [:segments]
    }.freeze

    def self.webhook_content_layouts
      {
        '1' => I18n.t('admin.shared.filter_jsinit.simple_layout'),
        '2' => I18n.t('admin.shared.filter_jsinit.advanced_layout')
      }
    end

    def self.checkbox_options
      {
        '0' => I18n.t('admin.shared.filter_jsinit.checked'),
        '1' => I18n.t('admin.shared.filter_jsinit.unchecked')
      }
    end

    def self.readable_conditions
      { 
        "from_email" => [I18n.t('requester_email')],
        "to_email" => [I18n.t('to_email')],
        "ticlet_cc" => [I18n.t('ticket_cc')],
        "subject" => [I18n.t('ticket.subject')],
        "description" => [I18n.t('description')],
        "subject_or_description" => [I18n.t('subject_or_description')],
        "last_interaction" => [I18n.t('last_interaction')],
        "priority" => [I18n.t('ticket.priority'), TicketConstants::PRIORITY_NAMES_BY_STR],
        "ticket_type" => [I18n.t('ticket.type')],
        "status" => [I18n.t('ticket.status'), "ticket_statuses", "status_id"],
        "source" => [I18n.t('ticket.source'), TicketConstants.readable_source_names_by_key],
        "product_id" => [I18n.t('admin.products.product_label_msg'), "products", "id"],
        "created_at" => [I18n.t('ticket.created_during.title'), VAConfig::CREATED_DURING_NAMES_BY_KEY],
        "updated_at" => [I18n.t('ticket.updated_during.title'), VAConfig::CREATED_DURING_NAMES_BY_KEY],
        "responder_id" => [I18n.t('ticket.agent'), "technicians", "id"],
        "group_id" => [I18n.t('ticket.group'), "groups", "id"],
        "internal_agent_id" => [I18n.t('ticket.internal_agent'), "technicians", "id"],
        "internal_group_id" => [I18n.t('ticket.internal_group'), "groups", "id"],
        "tag_ids" => [I18n.t('ticket.tag_condition'), "tags", "id"],
        "requester_email" => [I18n.t('requester_email')],
        "requester_name" =>  [I18n.t('requester_name')],
        "requester_job_title" => [I18n.t('requester_title')],
        "requester_time_zone" => [I18n.t('requester_time_zone')],
        "requester_language" => [I18n.t('requester_language'), READABLE_LANGUAGE_NAMES_BY_KEY],
        "company_name" => [I18n.t('company_name')],
        "company_domains" => [I18n.t('company_domain')],
        "created_at_supervisor" => [I18n.t('ticket.created_at')],
        "pending_since" => [I18n.t('ticket.pending_since')],
        "resolved_at" => [I18n.t('ticket.resolved_at')],
        "closed_at" => [I18n.t('ticket.closed_at')],
        "opened_at" => [I18n.t('ticket.opened_at')],
        "first_assigned_at" => [I18n.t('ticket.first_assigned_at')],
        "assigned_at" => [I18n.t('ticket.assigned_at')],
        "requester_responded_at" => [I18n.t('ticket.requester_responded_at')],
        "agent_responded_at" => [I18n.t('ticket.agent_responded_at')],
        "frDueBy" => [I18n.t('ticket.first_response_due')],
        "due_by" => [I18n.t('ticket.due_by')]
      }
    end

    def self.readable_events
      {
        "priority" => [I18n.t('observer_events.priority'), TicketConstants::PRIORITY_NAMES_BY_STR],
        "ticket_type" => [I18n.t('observer_events.type')],
        "status" => [I18n.t('observer_events.status'), "ticket_statuses", "status_id"],
        "group_id" => [I18n.t('observer_events.group'), "groups", "id"],
        "responder_id" => [I18n.t('observer_events.agent'), "technicians", "id"],
        "note_type" => [I18n.t('observer_events.note'), {
                          "--" => I18n.t('any_val.any'),
                          "public" => I18n.t('ticket.public_note'),
                          "private" => I18n.t('ticket.private_note')
                       }],
        "reply_sent" => [I18n.t('observer_events.reply')],
        "due_by" => [I18n.t('observer_events.due_date')],
        "ticket_action" => [I18n.t('observer_events.ticket'), {
                              "update" => I18n.t('ticket.updated'),
                              "delete" => I18n.t('ticket.deleted'),
                              "marked_spam" => I18n.t('ticket.marked_spam')
                            }],
        "time_sheet_action" => [I18n.t('observer_events.time_entry'), {
                                  "added" => I18n.t('ticket.new_time_entry'),
                                  "updated" => I18n.t('ticket.updated_time_entry')
                                }],
        "customer_feedback" => [I18n.t('observer_events.customer_feedback'), 
                                "active_custom_survey_choices", "face_value"],
        "mail_del_failed_requester" => [I18n.t('observer_events.mail_del_failed_requester')],
        "mail_del_failed_others" => [I18n.t('observer_events.mail_del_failed_others')]
      }
    end

    def self.readable_actions
      {
        "priority" => [I18n.t('set_priority_as'), TicketConstants::PRIORITY_NAMES_BY_STR],
        "ticket_type" => [I18n.t('set_type_as')],
        "status" => [I18n.t('set_status_as'), "ticket_statuses", "status_id"],
        "add_comment" => [I18n.t('add_note')],
        "add_tag" => [I18n.t('add_tags')],
        "add_a_cc" => [I18n.t('add_a_cc')],
        "add_watcher" => [I18n.t('dispatch.add_watcher'), "technicians", "id"],
        "trigger_webhook" => [I18n.t('trigger_webhook')],
        "responder_id" => [I18n.t('ticket.assign_to_agent'), "technicians", "id"],
        "group_id" => [I18n.t('email_configs.info9'), "groups", "id"],
        "product_id" => [I18n.t('admin.products.assign_product'), "products", "id"],
        "send_email_to_group" => [I18n.t('send_email_to_group')],
        "send_email_to_agent" => [I18n.t('send_email_to_agent')],
        "send_email_to_requester" => [I18n.t('send_email_to_requester')],
        "forward_ticket" => [I18n.t('forward_ticket')],
        "delete_ticket" => [I18n.t('delete_the_ticket')],
        "mark_as_spam" => [I18n.t('mark_as_spam')],
        "skip_notification" => [I18n.t('dispatch.skip_notifications')],
        "internal_group_id" => [I18n.t('ticket.assign_to_internal_group'), "groups", "id"],
        "internal_agent_id" => [I18n.t('ticket.assign_to_internal_agent'), "technicians", "id"]
      }
    end

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
