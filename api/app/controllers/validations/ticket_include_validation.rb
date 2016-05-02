class TicketIncludeValidation < ApiValidation
  attr_accessor :include, :include_array

  validates :include, data_type: { rules: String }
  validate :validate_include, if: -> { errors[:include].blank? && include }

  def validate_include
    @include_array = include.split(',').map!(&:strip)
    unless @include_array.present? && (@include_array - ApiTicketConstants::ALLOWED_INCLUDE_PARAMS).blank?
      errors[:include] << :not_included
      (self.error_options ||= {}).merge!(include: { list: ApiTicketConstants::ALLOWED_INCLUDE_PARAMS.join(', ') })
    end
  end
end
