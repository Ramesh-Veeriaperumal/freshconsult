module Admin::AccountFeatureConstants
  CREATE_FIELDS = DESTROY_FIELDS = %i[name].freeze
  ALLOWED_FEATURE_FOR_PRIVATE_API = %i[help_widget cascade_dispatcher freshreports_analytics disable_old_reports].freeze
  VALIDATION_CLASS = 'FeatureValidation'.freeze
  ALLOWED_METHOD_FOR_PRIVATE_API = [:create, :destroy].freeze
end
