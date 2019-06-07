module Solutions::HomeConstants
  SUMMARY_FIELDS = %w[portal_id language].freeze
  VALIDATION_CLASS = 'ApiSolutions::HomeValidation'.freeze
  DELEGATOR_CLASS  = 'ApiSolutions::HomeDelegator'.freeze
  LOAD_OBJECT_EXCEPT = %w[summary quick_views].freeze
  QUICK_VIEWS_FIELDS = %w[portal_id language].freeze
  PORTAL_ID_DEPENDANT_ACTIONS = %i[summary quick_views].freeze
end
