module BotConstants
  LOAD_OBJECT_EXCEPT = [:index, :new, :create, :training_completed].freeze
  VALIDATION_CLASS   = 'BotValidation'.freeze
  DELEGATOR_CLASS    = 'BotDelegator'.freeze
  NEW_FIELDS         = %w[portal_id].freeze
  CREATE_FIELDS      = %w[name avatar portal_id header theme_colour widget_size bot].freeze
  UPDATE_FIELDS      = CREATE_FIELDS
  MAP_CATEGORIES_FIELDS = %w[category_ids].freeze
  ENABLE_ON_PORTAL_FIELDS = %w[enable_on_portal].freeze
  IRIS_NOTIFICATION_TYPE = 'bot_training_completion'.freeze
  BOT_STATUS = {
    training_not_started: 1,
    training_inprogress: 2,
    training_completed: 3
  }.freeze
  DEFAULT_BOT_THEME_COLOUR = '#039a7b'.freeze
  DEFAULT_WIDGET_SIZE = 'STANDARD'.freeze
end
