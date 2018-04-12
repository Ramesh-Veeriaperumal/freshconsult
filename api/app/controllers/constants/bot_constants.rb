module BotConstants
  LOAD_OBJECT_EXCEPT = [:index, :new, :create].freeze
  VALIDATION_CLASS   = 'BotValidation'.freeze
  DELEGATOR_CLASS    = 'BotDelegator'.freeze
  NEW_FIELDS         = %w[portal_id].freeze
  CREATE_FIELDS      = %w[name avatar portal_id header theme_colour widget_size bot].freeze
  UPDATE_FIELDS      = CREATE_FIELDS
  DEFAULT_BOT_THEME_COLOUR = '#039a7b'
  DEFAULT_WIDGET_SIZE = 'STANDARD'
  BOT_STATUS = {
                 training_not_started: 1,
                 training_inprogress: 2,
                 training_completed: 3
               }.freeze
  WIDGET_CODE_DEFAULT_USER_NAME  = 'Guest'.freeze
end