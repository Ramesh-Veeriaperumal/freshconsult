module BotConstants
  LOAD_OBJECT_EXCEPT        = [:index, :new, :create, :training_completed].freeze

  VALIDATION_CLASS          = 'BotValidation'.freeze
  DELEGATOR_CLASS           = 'BotDelegator'.freeze
  SOLUTION_DELEGATOR_CLASS  = 'BotSolutionDelegator'.freeze
  SOLUTION_VALIDATION_CLASS = 'BotSolutionValidation'.freeze

  NEW_FIELDS                = %w[portal_id].freeze
  CREATE_FIELDS             = %w[name avatar portal_id header theme_colour widget_size bot].freeze
  UPDATE_FIELDS             = CREATE_FIELDS + %w[email_channel].freeze
  MAP_CATEGORIES_FIELDS     = %w[category_ids].freeze
  ENABLE_ON_PORTAL_FIELDS   = %w[enable_on_portal].freeze
  CREATE_BOT_FOLDER_FIELDS  = %w[category_id name description visibility].freeze
  ANALYTICS_FIELDS          = %w[start_date end_date].freeze

  IRIS_NOTIFICATION_TYPE    = 'bot_training_completion'.freeze

  BOT_STATUS = {
    training_not_started: 1,
    training_inprogress: 2,
    training_completed: 3
  }.freeze

  DEFAULT_BOT_THEME_COLOUR = '#039a7b'.freeze
  DEFAULT_WIDGET_SIZE = 'STANDARD'.freeze

  DEFAULT_ANALYTICS_HASH = {
    total_questions: 0,
    not_helpful: 0,
    attempted: 0,
    helpful: 0,
    not_attempted: 0,
    initiated_chats: 0
  }.freeze

  WIDGET_CODE_SELF_INIT = 'false'.freeze
  WIDGET_CODE_INIT_TYPE = 'normal'.freeze

  SKIP_BOT_API = ["email_channel"].freeze
end

