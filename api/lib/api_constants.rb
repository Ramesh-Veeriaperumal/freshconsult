module ApiConstants
  # *********************************-- MetalModulesConstants --*********************************************

  METAL_MODULES = [ # Do not change the order of modules included
    ActionController::Head, # needed when calling head
    ActionController::Helpers, # needed for calling methods which are defined as helper methods.
    ActionController::Redirecting,
    ActionController::Rendering,
    ActionController::RackDelegation,  # Needed so that reqeest and response method will be delegated to Rack
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

  CATEGORY_FIELDS = ['name', 'description']
  FORUM_FIELDS = ['name', 'description', 'forum_category_id', 'forum_type', 'forum_visibility', 'customers', 'customers' => []]
  UPDATE_TOPIC_FIELDS = { all: %w(title message_html stamp_type), edit_topic: ['sticky', 'locked'], manage_forums: ['forum_id'] }
  CREATE_TOPIC_FIELDS = UPDATE_TOPIC_FIELDS.merge(manage_users: ['email', 'user_id'])
  UPDATE_POST_FIELDS = { all: ['body_html', 'answer'] }
  CREATE_POST_FIELDS = { all: %w(body_html answer topic_id), manage_users: ['email', 'user_id'] }

  # *********************************-- ValidationConstants --*********************************************

  BOOLEAN_VALUES = ['0', 0, false, '1', 1, true] # for boolean fields all these values are accepted.
  LIST_FIELDS = {
    forum_visibility: Forum::VISIBILITY_KEYS_BY_TOKEN.values.join(','),
    forum_type: Forum::TYPE_KEYS_BY_TOKEN.values.join(','),
    sticky: BOOLEAN_VALUES.map(&:to_s).uniq.join(','),
    locked: BOOLEAN_VALUES.map(&:to_s).uniq.join(','),
    answer: BOOLEAN_VALUES.map(&:to_s).uniq.join(',')
  }

  FORUM_VISIBILITY_KEYS_BY_TOKEN = Forum::VISIBILITY_KEYS_BY_TOKEN.values | Forum::VISIBILITY_KEYS_BY_TOKEN.values.map(&:to_s)
  FORUM_TYPE_KEYS_BY_TOKEN = Forum::TYPE_KEYS_BY_TOKEN.values | Forum::TYPE_KEYS_BY_TOKEN.values.map(&:to_s)
  FORMATTED_TYPES = [ActiveSupport::TimeWithZone]

  # *********************************-- ErrorConstants --*********************************************

  API_ERROR_CODES = {
    already_exists: ['has already been taken', 'already exists in the selected category'],
    invalid_value: ["can't be blank", 'is not included in the list', 'invalid_user'],
    datatype_mismatch: ['is not a date', 'is not a number'],
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
