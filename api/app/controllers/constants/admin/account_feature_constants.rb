module Admin::AccountFeatureConstants
  CREATE_FIELDS = DESTROY_FIELDS = %i[name].freeze
  ALLOWED_FEATURE_FOR_PRIVATE_API = %i[cascade_dispatcher cascade_dispatchr].freeze
  VALIDATION_CLASS = 'FeatureValidation'.freeze
  ALLOWED_METHOD_FOR_PRIVATE_API = [:create, :destroy].freeze
end
