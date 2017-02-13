module ApiTicketConstants
  # ControllerConstants
  ARRAY_FIELDS = %w(tags cc_emails attachments attachment_ids).freeze
  HASH_FIELDS = ['custom_fields'].freeze
  COMPLEX_FIELDS = ARRAY_FIELDS | HASH_FIELDS

  CREATE_FIELDS = %w(description due_by email_config_id fr_due_by group_id priority
                     email phone twitter_id facebook_id requester_id name
                     responder_id source status subject type product_id company_id
                  ).freeze | ARRAY_FIELDS | HASH_FIELDS | AttachmentConstants::CLOUD_FILE_FIELDS
  UPDATE_FIELDS = %w(description due_by email_config_id fr_due_by group_id priority
                     email phone twitter_id facebook_id requester_id name
                     responder_id source status subject type product_id company_id
                  ).freeze | (ARRAY_FIELDS - ['cc_emails']) | HASH_FIELDS | AttachmentConstants::CLOUD_FILE_FIELDS
  BULK_REPLY_FIELDS = [reply: ([:body, :from_email, :attachment_ids] | AttachmentConstants::CLOUD_FILE_FIELDS)].freeze
  BULK_UPDATE_FIELDS = ((UPDATE_FIELDS - ['attachments']) | %w(skip_close_notification)).freeze
  EXECUTE_SCENARIO_FIELDS = BULK_EXECUTE_SCENARIO_FIELDS = %w(scenario_id).freeze
  COMPOSE_EMAIL_FIELDS = (CREATE_FIELDS - %w(source product_id responder_id requester_id phone twitter_id facebook_id)).freeze
  SHOW_FIELDS = ['include'].freeze
  UPDATE_PROPERTIES_FIELDS = %w(due_by responder_id group_id status priority tags  skip_close_notification).freeze
  
  ALLOWED_INCLUDE_PARAMS = %w(conversations requester company stats survey).freeze
  SIDE_LOADING = %w(requester stats company survey).freeze
  INCLUDE_PRELOAD_MAPPING = { 'stats' => :ticket_states }.freeze
  BULK_DELETE_PRELOAD_OPTIONS = [:tags, :schema_less_ticket].freeze
  ORDER_TYPE = TicketsFilter::SORT_ORDER_FIELDS.map(&:first).map(&:to_s).freeze
  ORDER_BY = TicketsFilter::SORT_FIELDS.map(&:first).map(&:to_s) - ['priority']
  DEFAULT_ORDER_BY = TicketsFilter::DEFAULT_SORT
  DEFAULT_ORDER_TYPE = TicketsFilter::DEFAULT_SORT_ORDER
  VALIDATABLE_DELEGATOR_ATTRIBUTES = %w(group_id responder_id product_id
                                        email_config_id custom_field requester_id
                                        status facebook_id ticket_type company_id).freeze
  PRIORITIES = TicketConstants::PRIORITY_TOKEN_BY_KEY.keys.freeze
  SOURCES = TicketConstants::SOURCE_KEYS_BY_TOKEN.slice(:email, :portal, :phone, :chat, :mobihelp, :feedback_widget).values.freeze

  PIPE_CREATE_FIELDS = CREATE_FIELDS | %w( pending_since created_at updated_at )
  
  SCOPE_BASED_ON_ACTION = {
    'update'  => { deleted: false, spam: false },
    'restore' => { deleted: true, spam: false },
    'destroy' => { deleted: false, spam: false }
  }.freeze

  # all_tickets is not included because it is the default filter applied.
  # monitored_by is renamed as 'watching'
  FILTER = %w(new_and_my_open watching spam deleted).freeze

  FIELD_TYPES = Helpdesk::TicketField::FIELD_CLASS.keys.map(&:to_s).freeze
  INDEX_FIELDS = %w(filter company_id requester_id email order_by order_type updated_since include).freeze
  INDEX_FILTER_FIELDS = %w(filter company_id requester_id email updated_since).freeze

  ATTRIBUTES_TO_BE_STRIPPED = %w(email phone name subject type tags cc_emails twitter_id custom_fields).freeze

  CLOSED = Helpdesk::Ticketfields::TicketStatus::CLOSED
  RESOLVED = Helpdesk::Ticketfields::TicketStatus::RESOLVED
  PENDING = Helpdesk::Ticketfields::TicketStatus::PENDING

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

  PERMISSION_REQUIRED = [:show, :update, :execute_scenario, :spam, :unspam, :restore, :destroy].freeze

  REQUIRE_PRELOAD = [:bulk_delete, :bulk_spam, :bulk_unspam, :bulk_restore].freeze
  BULK_ACTION_ASYNC_METHODS = [:bulk_execute_scenario, :bulk_update, :delete_forever].freeze
  BULK_ACTION_METHODS = [:bulk_delete, :bulk_spam, :bulk_restore, :bulk_unspam] + BULK_ACTION_ASYNC_METHODS

  LOAD_OBJECT_EXCEPT = (BULK_ACTION_METHODS + [:merge, :empty_trash, :empty_spam]).freeze

  MAX_EMAIL_COUNT = TicketConstants::MAX_EMAIL_COUNT - 1

  FIELD_MAPPINGS = { group: :group_id, agent: :responder_id, responder: :responder_id, requester: :requester_id, email_config: :email_config_id,
                     product: :product_id, ticket_type: :type }.freeze

  SEARCH_ALLOWED_DEFAULT_FIELDS = ['status'].freeze

  BACKGROUND_THRESHOLD = 5

  NO_CONTENT_TYPE_REQUIRED = [:restore, :spam, :unspam].freeze

  VALIDATION_CLASS = 'TicketValidation'.freeze
  DELEGATOR_CLASS = 'TicketDelegator'.freeze

  MERGE_PARAMS = [:primary_id, :ticket_ids, :convert_recepients_to_cc, note_in_primary: [:body, :private], note_in_secondary: [:body, :private]].freeze

  PARAMS_TO_REMOVE = [:cc_emails, :description].freeze
  PARAMS_MAPPINGS = { custom_fields: :custom_field, fr_due_by: :frDueBy, type: :ticket_type }.freeze
  PARAMS_TO_SAVE_AND_REMOVE = [:status, :cloud_files, :attachment_ids, :skip_close_notification].freeze
end.freeze
