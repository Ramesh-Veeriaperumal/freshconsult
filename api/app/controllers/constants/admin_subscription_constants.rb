module AdminSubscriptionConstants
  LOAD_OBJECT_EXCEPT = [:plans]
  PLANS_FIELDS = %w(currency).freeze
  VALIDATION_CLASS = 'AdminSubscriptionValidation'.freeze
end