module SubscriptionConstants
  # ControllerConstants
  WATCH_FIELDS = %w(user_id).freeze
  # Wrap parameters args
  WRAP_PARAMS = [:subscription, exclude: [], format: [:json]].freeze

  TICKET_PERMISSION_REQUIRED = [:watch, :unwatch, :watchers].freeze
   # Routes that doesn't accept any params
  NO_PARAM_ROUTES = %w(unwatch).freeze

  NO_CONTENT_TYPE_REQUIRED = [:watch, :unwatch].freeze

end.freeze
