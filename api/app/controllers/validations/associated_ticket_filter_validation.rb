class AssociatedTicketFilterValidation < TicketFilterValidation
  ALLOWED_INCLUDE_PARAMS = %w[count].freeze

  def validate_include
    @include_array = include.split(',').map!(&:strip)
    if @include_array.blank? || (@include_array - ALLOWED_INCLUDE_PARAMS).present?
      errors[:include] << :not_included
      (self.error_options ||= {}).merge!(include: { list: ALLOWED_INCLUDE_PARAMS.join(', ') })
    end
  end
end
