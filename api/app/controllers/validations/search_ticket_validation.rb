class SearchTicketValidation < ApiValidation
  attr_accessor :include

  validates :include, data_type: { rules: String }
  validate :validate_include, if: -> { errors[:include].blank? && include }

  ALLOWED_INCLUDE_PARAMS = ['custom_fields'].freeze

  def validate_include
    @include_array = include.split(',').map!(&:strip)
    if @include_array.blank? || (@include_array - allowed_include_params).present?
      errors[:include] << :not_included
      (self.error_options ||= {}).merge!(include: { list: allowed_include_params.join(', ') })
    end
  end

  def allowed_include_params
    ALLOWED_INCLUDE_PARAMS
  end
end
