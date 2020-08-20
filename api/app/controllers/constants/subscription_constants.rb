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

  FREDDY_ADDONS = {
    Subscription::Addon::FREDDY_SELF_SERVICE_ADDON => 'freddy_self_service',
    Subscription::Addon::FREDDY_ULTIMATE_SESSION_ADDON => 'freddy_ultimate',
    Subscription::Addon::FREDDY_ULTIMATE_ADDON => 'freddy_ultimate',
    Subscription::Addon::FREDDY_SESSION_PACKS_ADDON => 'freddy_session_packs'
  }.freeze

  FREDDY_SESSION_PACK_ADDONS = [
    Subscription::Addon::FREDDY_MONTHLY_SESSION_PACKS_ADDON,
    Subscription::Addon::FREDDY_QUARTERLY_SESSION_PACKS_ADDON,
    Subscription::Addon::FREDDY_HALF_YEARLY_SESSION_PACKS_ADDON,
    Subscription::Addon::FREDDY_ANNUAL_SESSION_PACKS_ADDON
  ].freeze

  ADDON_PARAMS_NAMES_MAP = [FSM_ADDON_PARAMS_NAMES_MAP, FREDDY_ADDONS].reduce(&:merge)

  ON_OFF_ADDONS = Set[:freddy_self_service].freeze

  FDFSONBOARDING = 'freshsales_freshdesk_onboarding'.freeze
  FRESHSALES = 'freshsales'.freeze
  FDFSBUNDLE = 'FDFSBUNDLE'.freeze
  POSTPONE_NOTIFICATION_OFFSET = -3
end.freeze
