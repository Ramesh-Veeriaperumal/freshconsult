module Ember::Solutions::TemplateConstants
  TEMPLATE_FIELDS = %w[title description is_active is_default].freeze
  CREATE_FIELDS = UPDATE_FIELDS = TEMPLATE_FIELDS

  VALIDATION_CLASS = 'SolutionTemplateValidation'.freeze
  DELEGATOR_CLASS = 'Ember::Solutions::TemplateDelegator'.freeze

  MAX_TEMPLATES_COUNT = 30
end
