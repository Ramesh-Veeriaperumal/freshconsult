class CannedResponseFilterValidation < ApiValidation
  attr_accessor :include, :include_array, :ticket_id, :search_string

  validates :include, data_type: { rules: String }
  validate :validate_include, if: -> { errors[:include].blank? && include }

  validates :ticket_id, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true, ignore_string: :allow_string_param }
  validates :search_string, data_type: { rules: String, required: true }, if: :search?

  def validate_include
    @include_array = include.split(',').map!(&:strip)
    if @include_array.blank? || (@include_array - CannedResponseConstants::ALLOWED_INCLUDE_PARAMS).present?
      errors[:include] << :not_included
      (self.error_options ||= {}).merge!(include: { list: CannedResponseConstants::ALLOWED_INCLUDE_PARAMS.join(', ') })
    end
  end

  private

    def search?
      [:search].include?(validation_context)
    end
end
