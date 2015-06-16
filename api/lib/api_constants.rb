module ApiConstants
  # *********************************-- MetalModulesConstants --*********************************************

  METAL_MODULES = [ # Do not change the order of modules included
    ActionController::Head, # needed when calling head
    ActionController::Helpers, # needed for calling methods which are defined as helper methods.
    ActionController::Redirecting,
    ActionController::Rendering,
    ActionController::RackDelegation,  # Needed so that request and response method will be delegated to Rack
    ActionController::Caching,
    Rails.application.routes.url_helpers, # Need for location header in response
    ActiveSupport::Rescuable, # Dependency with strong params
    ActionController::MimeResponds,
    ActionController::ImplicitRender,
    ActionController::StrongParameters,
    ActionController::Cookies,
    ActionController::RequestForgeryProtection,
    ActionController::HttpAuthentication::Basic::ControllerMethods,
    AbstractController::Callbacks,
    ActionController::Rescue,
    ActionController::ParamsWrapper,
    ActionController::Instrumentation  # need this for active support instrumentation.
  ]

  # *********************************-- ControllerConstants --*********************************************

  API_CURRENT_VERSION = 'v2'
  CONTENT_TYPE_REQUIRED_METHODS = ['POST', 'PUT']
  DEFAULT_PAGINATE_OPTIONS = {
    per_page: 30,
    page: 1
  }
  DEFAULT_PARAMS = [:version, :format, :k].map(&:to_s)

  # *********************************-- DiscussionConstants --*********************************************

  CATEGORY_FIELDS = ['name', 'description']
  FORUM_FIELDS = ['name', 'description', 'forum_category_id', 'forum_type', 'forum_visibility', 'customers', 'customers' => []]
  UPDATE_TOPIC_FIELDS = { all: %w(title message_html stamp_type), edit_topic: ['sticky', 'locked'], manage_forums: ['forum_id'] }
  CREATE_TOPIC_FIELDS = UPDATE_TOPIC_FIELDS.merge(view_admin: ['created_at', 'updated_at'], manage_users: ['email', 'user_id'])
  UPDATE_POST_FIELDS = { all: ['body_html', 'answer'] }
  CREATE_POST_FIELDS = { all: %w(body_html answer topic_id), view_admin: ['created_at', 'updated_at'], manage_users: ['email', 'user_id'] }

  # *********************************-- TicketConstants --*********************************************

  TICKET_ARRAY_FIELDS = [{ 'tags' => [String] }, { 'cc_emails' => [String] }, { 'attachments' => [] }]
  CREATE_TICKET_FIELDS = %w(cc_emails description description_html due_by email_config_id fr_due_by group_id priority email phone twitter_id facebook_id requester_id name responder_id source status subject type product_id tags) | TICKET_ARRAY_FIELDS
  UPDATE_TICKET_FIELDS = %w(description description_html due_by email_config_id fr_due_by group_id priority email phone twitter_id facebook_id requester_id name responder_id source status subject type product_id tags) | TICKET_ARRAY_FIELDS.reject { |k| k['cc_emails'] }
  ASSIGN_TICKET_FIELDS = ['user_id']
  RESTORE_TICKET_FIELDS = []
  REPLY_NOTE_FIELDS = ['body', 'body_html', 'user_id', { 'cc_emails' => [String] }, { 'bcc_emails' => [String] }, 'ticket_id', { 'attachments' => [ActionDispatch::Http::UploadedFile] }]
  CREATE_NOTE_FIELDS = ['body', 'body_html', 'private', 'incoming', 'user_id', { 'notify_emails' => [String] }, 'ticket_id', { 'attachments' => [ActionDispatch::Http::UploadedFile] }]
  UPDATE_NOTE_FIELDS = ['body', 'body_html', { 'attachments' => [] }]
  TICKET_ORDER_TYPE = TicketsFilter::SORT_ORDER_FIELDS.map(&:first).map(&:to_s)
  TICKET_ORDER_BY = TicketsFilter::SORT_FIELDS.map(&:first).map(&:to_s)
  TICKET_FILTER = TicketsFilter::DEFAULT_VISIBLE_FILTERS.values_at(0, 2, 3, 4)
  DELETED_SCOPE = {
    'update' => false,
    'assign' => false,
    'restore' => true,
    'destroy' => false
  }
  INDEX_TICKET_FIELDS = %w(filter company_id requester_id order_by order_type)

  # *********************************-- TicketFieldConstants --*********************************************

  TICKET_FIELD_TYPES = Helpdesk::TicketField::FIELD_CLASS.keys.map(&:to_s)

  NOTE_TYPE_FOR_ACTION = {
    'create' => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
    'reply'  => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['email']
  }

  # *********************************-- ValidationConstants --*********************************************

  BOOLEAN_VALUES = ['0', 0, false, '1', 1, true] # for boolean fields all these values are accepted.
  LIST_FIELDS = {
    forum_visibility: Forum::VISIBILITY_KEYS_BY_TOKEN.values.join(','),
    forum_type: Forum::TYPE_KEYS_BY_TOKEN.values.join(','),
    sticky: BOOLEAN_VALUES.map(&:to_s).uniq.join(','),
    locked: BOOLEAN_VALUES.map(&:to_s).uniq.join(','),
    answer: BOOLEAN_VALUES.map(&:to_s).uniq.join(','),
    priority: TicketConstants::PRIORITY_TOKEN_BY_KEY.keys.join(','),
    source:  TicketConstants::SOURCE_KEYS_BY_TOKEN.except(:twitter, :forum, :facebook).values.join(','),
    private: BOOLEAN_VALUES.map(&:to_s).uniq.join(','),
    incoming: BOOLEAN_VALUES.map(&:to_s).uniq.join(','),
    order_type: TICKET_ORDER_TYPE.join(','),
    order_by: TICKET_ORDER_BY.join(','),
    filter: TICKET_FILTER.join(',')
  }

  EMAIL_REGEX = /\b[-a-zA-Z0-9.'’&_%+]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,15}\b/

  FORUM_VISIBILITY_KEYS_BY_TOKEN = Forum::VISIBILITY_KEYS_BY_TOKEN.values | Forum::VISIBILITY_KEYS_BY_TOKEN.values.map(&:to_s)
  FORUM_TYPE_KEYS_BY_TOKEN = Forum::TYPE_KEYS_BY_TOKEN.values | Forum::TYPE_KEYS_BY_TOKEN.values.map(&:to_s)
  FORMATTED_TYPES = [ActiveSupport::TimeWithZone]
  UPLOADED_FILE_TYPE = ActionDispatch::Http::UploadedFile

  # *********************************-- ErrorConstants --*********************************************

  API_ERROR_CODES = {
    already_exists: ['has already been taken', 'already exists in the selected category'],
    invalid_value: ["can't be blank", 'is not included in the list', 'invalid_user', 'is not a valid email'],
    datatype_mismatch: ['is not a date', 'is not a number', 'is not a/an Array', 'is not a/an Hash'],
    invalid_field: ['invalid_field']
  }

  API_HTTP_ERROR_STATUS_BY_CODE = {
    already_exists: 409
  }

  # Reverse mapping, this will result in:
  # {'has already been taken' => :already_exists,
  # 'already exists in the selected category' => :already_exists
  # 'can't be blank' => :invalid_value
  # ...}
  API_ERROR_CODES_BY_VALUE = Hash[*API_ERROR_CODES.flat_map { |code, errors| errors.flat_map { |error| [error, code] } }]

  DEFAULT_CUSTOM_CODE = 'invalid_value'
  DEFAULT_HTTP_CODE = 400
end
