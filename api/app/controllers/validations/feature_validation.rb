class FeatureValidation < ApiValidation
  include Admin::AccountFeatureConstants

  attr_accessor :name

  validates :name, presence: true, data_type: { rules: String, allow_nil: false }, if: 'feature_method?'
  validate :allowed_feature?, if: 'feature_method?'

  private

  def allowed_feature?
    unless ALLOWED_FEATURE_FOR_PRIVATE_API.include?(name.to_sym)
      errors[:feature] << :invalid_feature_name
      error_options[:feature] = {feature_name: name}
    end
  end

  def feature_method?
    ALLOWED_METHOD_FOR_PRIVATE_API.include?(validation_context)
  end
end
