module AdvancedTicketingConstants
  LOAD_OBJECT_EXCEPT = %w[insights].freeze
  VALIDATION_CLASS = 'AdvancedTicketingValidation'.freeze
  DELEGATOR_CLASS = 'AdvancedTicketingDelegator'.freeze
  CREATE_FIELDS = %w[name].freeze
  ADVANCED_TICKETING_APPS = %w[parent_child_tickets link_tickets shared_ownership].freeze
  S3_FILE_PATH = 'advanced_ticketing/metrics.json'.freeze
  REDIS_EXPIRY = '604800'.freeze #One week
end