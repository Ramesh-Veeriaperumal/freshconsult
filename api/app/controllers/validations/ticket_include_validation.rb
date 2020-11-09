class TicketIncludeValidation < ApiValidation
  attr_accessor :include, :include_array

  validates :include, data_type: { rules: String }
  validate :validate_include, if: -> { errors[:include].blank? && include }

  def validate_include
    @include_array = include.split(',').map!(&:strip)
    if @include_array.blank? || (@include_array - allowed_include_params).present?
      errors[:include] << :not_included
      (self.error_options ||= {}).merge!(include: { list: allowed_include_params.join(', ') })
    elsif @include_array.include?('survey') && !Account.current.new_survey_enabled?
      errors[:include] << :require_feature
      (self.error_options ||= {}).merge!(include: { feature: 'Custom survey' })
    end
  end

  def allowed_include_params
    # TODO: Need to implement include associates for public API
    private_api? ? ApiTicketConstants::ALLOWED_INCLUDE_PARAMS : (ApiTicketConstants::ALLOWED_INCLUDE_PARAMS - ['survey', 'associates'])
  end
end
