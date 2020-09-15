module AdminSubscriptionConstants
  LOAD_OBJECT_EXCEPT = %w[:plans].freeze
  SHOW_FIELDS = %w[include].freeze
  PLANS_FIELDS = %w[currency].freeze
  FETCH_PLAN_FIELDS = %w[currency].freeze
  UPDATE_FIELDS = [:plan_id, :renewal_period, :agent_seats, :currency].freeze
  ESTIMATE_FIELDS = %w[agent_seats plan_id renewal_period currency].freeze
  ESTIMATE_FEATURE_LOSS_FIELDS = ['plan_id'].freeze
  ALLOWED_INCLUDE_PARAMS = %w[update_payment_site].freeze
  VALIDATION_CLASS = 'AdminSubscriptionValidation'.freeze
  DELEGATOR_CLASS = 'AdminSubscriptionDelegator'.freeze
  VALID_BILLING_CYCLES = SubscriptionPlan::BILLING_CYCLE.collect { |i| i[2] }.freeze
end
