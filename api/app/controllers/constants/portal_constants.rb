module PortalConstants
  HELPDESK_FIELDS = %w[primary_background nav_background].freeze
  UPDATE_FIELDS = %w[name host default product_id ssl_enabled solution_category_ids discussion_category_ids created_at updated_at helpdesk_logo preferences].freeze
  DELEGATOR_CLASS = 'PortalDelegator'.freeze
  VALIDATION_CLASS = 'PortalValidation'.freeze
end.freeze
