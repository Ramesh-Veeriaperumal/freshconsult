module SubscriptionConstants
  # ControllerConstants
  WATCH_FIELDS = BULK_WATCH_FIELDS = %w(user_id).freeze
  # Wrap parameters args
  WRAP_PARAMS = [:subscription, exclude: [], format: [:json]].freeze

  TICKET_PERMISSION_REQUIRED = [:watch, :unwatch, :watchers].freeze
  # Routes that doesn't accept any params
  NO_PARAM_ROUTES = %w(unwatch).freeze

  NO_CONTENT_TYPE_REQUIRED = [:watch, :unwatch].freeze

  BULK_ACTION_METHODS = [:bulk_watch, :bulk_unwatch].freeze

  LOAD_OBJECT_EXCEPT = BULK_ACTION_METHODS.freeze

  VALIDATION_CLASS = 'SubscriptionValidation'.freeze
  DELEGATOR_CLASS = 'SubscriptionDelegator'.freeze
  FSM_ADDON_PARAMS_NAMES_MAP = {
    Subscription::Addon::FSM_ADDON => 'field_service_management',
    Subscription::Addon::FSM_ADDON_2020 => 'field_service_management'
  }.freeze
  FDFSONBOARDING = 'freshsales_freshdesk_onboarding'.freeze
  FRESHSALES = 'freshsales'.freeze
  FDFSBUNDLE = 'FDFSBUNDLE'.freeze
  POSTPONE_NOTIFICATION_OFFSET = -3
end.freeze
