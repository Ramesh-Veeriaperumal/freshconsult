module AdminSubscriptionConstants
  LOAD_OBJECT_EXCEPT = [:plans]
  PLANS_FIELDS = %w[currency].freeze
  UPDATE_FIELDS = [:plan_id, :renewal_period, :agent_seats].freeze
  ESTIMATE_FIELDS = %w[agent_seats plan_id renewal_period].freeze
  VALIDATION_CLASS = 'AdminSubscriptionValidation'.freeze
  DELEGATOR_CLASS = 'AdminSubscriptionDelegator'.freeze
  VALID_BILLING_CYCLES = SubscriptionPlan::BILLING_CYCLE.collect{ |i| i[2] }.freeze
end
