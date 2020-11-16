module ApiTicketConstants
  # ControllerConstants
  ARRAY_FIELDS = %w(tags cc_emails attachments attachment_ids related_ticket_ids inline_attachment_ids).freeze
  HASH_FIELDS = ['custom_fields'].freeze
  COMPLEX_FIELDS = ARRAY_FIELDS | HASH_FIELDS
  IGNORE_PARAMS = %w[skip_close_notification parent_template_id child_template_ids topic_id].freeze | AttachmentConstants::CLOUD_FILE_FIELDS

  CREATE_FIELDS = %w(description due_by email_config_id fr_due_by group_id internal_group_id priority
                     email phone twitter_id facebook_id requester_id name
                     responder_id internal_agent_id source status subject type product_id company_id
                     parent_id parent_template_id child_template_ids unique_external_id topic_id fc_call_id).freeze | ARRAY_FIELDS | HASH_FIELDS | AttachmentConstants::CLOUD_FILE_FIELDS

  # removed source since update of ticket source should not be allowed. - Might break API v2
  UPDATE_FIELDS = %w(description due_by email_config_id fr_due_by group_id internal_group_id priority
                     email phone twitter_id facebook_id requester_id name
                     responder_id internal_agent_id source status subject type product_id company_id skill_id
                     skip_close_notification unique_external_id tracker_id).freeze | (ARRAY_FIELDS - ['cc_emails']) | HASH_FIELDS | AttachmentConstants::CLOUD_FILE_FIELDS
  PARSE_TEMPLATE_FIELDS = [:template_text].freeze
  BULK_REPLY_FIELDS = [reply: ([:body, :from_email, :attachment_ids, :inline_attachment_ids] | AttachmentConstants::CLOUD_FILE_FIELDS)].freeze
  BULK_UPDATE_FIELDS = (UPDATE_FIELDS - ['attachments']).freeze
  BULK_ARCHIVE_FIELDS = %w[archive_days].freeze
  EXECUTE_SCENARIO_FIELDS = BULK_EXECUTE_SCENARIO_FIELDS = %w(scenario_id).freeze
  COMPOSE_EMAIL_FIELDS = (CREATE_FIELDS - %w[product_id responder_id requester_id phone twitter_id facebook_id]).freeze
  SHOW_FIELDS = ['include'].freeze
  PERMITTED_ARCHIVE_FIELDS = SHOW_FIELDS
  FSM_FIELDS = [:cf_fsm_appointment_start_time, :cf_fsm_appointment_end_time].freeze
  UPDATE_PROPERTIES_CUSTOM_FIELDS = [custom_fields: FSM_FIELDS].freeze
  UPDATE_PROPERTIES_FIELDS = %w(due_by responder_id group_id status priority tags skip_close_notification subject description attachment_ids requester_id company_id inline_attachment_ids email).freeze | AttachmentConstants::CLOUD_FILE_FIELDS | UPDATE_PROPERTIES_CUSTOM_FIELDS

  ALLOWED_INCLUDE_PARAMS = %w(conversations requester company stats survey sla_policy associates).freeze
  EXCLUDABLE_FIELDS = ['custom_fields'].freeze
  SIDE_LOADING = %w[requester stats company survey description].freeze
  INCLUDE_PRELOAD_MAPPING = { 
    stats: :ticket_states,
    description: :ticket_body,
    requester: :requester
  }.freeze
  BULK_DELETE_PRELOAD_OPTIONS = [:tags, :schema_less_ticket].freeze
  DEFAULT_ORDER_BY = TicketsFilter::DEFAULT_SORT
  DEFAULT_ORDER_TYPE = TicketsFilter::DEFAULT_SORT_ORDER
  VALIDATABLE_DELEGATOR_ATTRIBUTES = %w(group_id responder_id product_id
                                        internal_agent_id internal_group_id
                                        email_config_id custom_field requester_id
                                        status facebook_id ticket_type
                                        unique_external_id skill_id).freeze

  PRIORITIES = TicketConstants::PRIORITY_TOKEN_BY_KEY.keys.freeze
  PIPE_CREATE_FIELDS = CREATE_FIELDS | %w(pending_since created_at updated_at on_state_time closed_at)
  PIPE_UPDATE_FIELDS = UPDATE_FIELDS | %w(pending_since created_at updated_at closed_at)

  CREATE_CHILD_WITH_TEMPLATE_FIELDS = %w(parent_template_id child_template_ids)

  SCOPE_BASED_ON_ACTION = {
    'restore' => { deleted: true, spam: false },
    'unspam' => { deleted: false, spam: true },
    'show' => {},
    'latest_note' => {}
  }.freeze

  CONDITIONS_FOR_TICKET_ACTIONS = { deleted: false, spam: false }.freeze

  # all_tickets is not included because it is the default filter applied.
  # monitored_by is renamed as 'watching'
  FILTER = %w(new_and_my_open watching spam deleted).freeze
  SPAM_DELETED_FILTER = ['spam', 'deleted'].freeze

  FIELD_TYPES = Helpdesk::TicketField::FIELD_CLASS.keys.map(&:to_s).freeze
  INDEX_FIELDS = %w(filter company_id requester_id email order_by order_type updated_since include).freeze
  INDEX_FILTER_FIELDS = %w(filter company_id requester_id email updated_since).freeze
  ASSOCIATED_TICKETS_FILTER = %w[type only include].freeze

  ATTRIBUTES_TO_BE_STRIPPED = %w(email phone name subject type tags cc_emails twitter_id custom_fields).freeze

  EXPORT_CSV_HASH_FIELDS = %w(ticket_fields contact_fields company_fields).freeze
  EXPORT_CSV_FIELDS = ['format', 'date_filter', 'ticket_state_filter', 'start_date', 'end_date', 'query_hash', 'filter_name'].freeze | EXPORT_CSV_HASH_FIELDS

  CLOSED = Helpdesk::Ticketfields::TicketStatus::CLOSED
  RESOLVED = Helpdesk::Ticketfields::TicketStatus::RESOLVED
  PENDING = Helpdesk::Ticketfields::TicketStatus::PENDING
  OPEN = Helpdesk::Ticketfields::TicketStatus::OPEN

  # Routes that doesn't accept any params
  NO_PARAM_ROUTES = %w(restore).freeze

  # Wrap parameters args
  WRAP_PARAMS = [:ticket, exclude: [], format: [:json, :multipart_form]].freeze
  MERGE_WRAP_PARAMS = [:merge, exclude: [], format: [:json]].freeze
  BULK_WRAP_PARAMS = [:bulk_action, exclude: [], format: [:json]].freeze

  ALLOWED_CONTENT_TYPE_FOR_ACTION = {
    create: [:json, :multipart_form],
    update: [:json, :multipart_form],
    bulk_delete: [:json],
    bulk_spam: [:json],
    bulk_unspam: [:json],
    bulk_restore: [:json],
    bulk_execute_scenario: [:json]
  }.freeze

  PERMISSION_REQUIRED = [:show, :update, :execute_scenario, :spam, :unspam, :restore, :destroy, :search, :update_properties, :create_child_with_template].freeze

  REQUIRE_PRELOAD = [:bulk_delete, :bulk_spam, :bulk_unspam, :bulk_restore].freeze
  BULK_ACTION_ASYNC_METHODS = [:bulk_execute_scenario, :bulk_update, :delete_forever, :bulk_delete, :bulk_spam, :bulk_restore, :bulk_unspam, :bulk_archive].freeze
  BULK_ACTION_METHODS = [:bulk_link, :bulk_unlink] + BULK_ACTION_ASYNC_METHODS

  LOAD_OBJECT_EXCEPT = (BULK_ACTION_METHODS + [:merge, :empty_trash, :empty_spam, :export_csv]).freeze

  MAX_EMAIL_COUNT = TicketConstants::MAX_EMAIL_COUNT - 1

  FIELD_MAPPINGS = { group: :group_id, agent: :responder_id, responder: :responder_id, requester: :requester_id, email_config: :email_config_id,
                     product: :product_id, ticket_type: :type }.freeze

  TICKETS_API_RELAXATION_MANDATORY_FIELDS_FOR_CREATE = ['subject', 'description', 'requester'].freeze

  SEARCH_ALLOWED_DEFAULT_FIELDS = ['status'].freeze

  BACKGROUND_THRESHOLD = 5

  NO_CONTENT_TYPE_REQUIRED = [:restore, :spam, :unspam].freeze

  VALIDATION_CLASS = 'TicketValidation'.freeze
  DELEGATOR_CLASS = 'TicketDelegator'.freeze

  MERGE_PARAMS = [:primary_id, :ticket_ids, :convert_recepients_to_cc, note_in_primary: [:body, :private], note_in_secondary: [:body, :private]].freeze

  BG_WORKER_ACTION_MAPPING = {
    bulk_delete: :destroy,
    bulk_restore: :restore,
    bulk_spam: :spam,
    bulk_unspam: :unspam
  }.freeze

  PARAMS_TO_REMOVE = [:cc_emails, :description, :parent_id].freeze
  PARAMS_MAPPINGS = { custom_fields: :custom_field, fr_due_by: :frDueBy, type: :ticket_type, tracker_id: :tracker_ticket_id }.freeze
  PARAMS_TO_SAVE_AND_REMOVE = [:status, :cloud_files, :attachment_ids, :skip_close_notification, :parent_template_id, :child_template_ids, :inline_attachment_ids, :topic_id, :fc_call_id].freeze

  ALLOWED_ONLY_PARAMS = %w(count).freeze
  VERIFY_REQUESTER_ON_PROPERTY_VALUE_CHANGES = %w(email phone twitter_id 
                                          facebook_id unique_external_id).freeze
  SECONDARY_TICKET_PARAMS = %w(tracker_id).freeze

  MAX_PAGE_LIMIT = 300

  TICKET_DELETE_DAYS = 30
  TICKET_DELETE_MESSAGE_TYPE = 'ticket_delete_message_type'.freeze
  TICKET_DELETE_SCHEDULER_TYPE = 'ticket_delete_scheduler_type'.freeze

  BULK_API_JOBS_CLASS = 'Ticket'.freeze
end.freeze
