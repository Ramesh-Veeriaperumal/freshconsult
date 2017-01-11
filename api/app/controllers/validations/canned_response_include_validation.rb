class CannedResponseIncludeValidation < ApiValidation
  attr_accessor :include, :include_array

  validates :include, data_type: { rules: String }
  validate :validate_include, if: -> { errors[:include].blank? && include }

  def validate_include
    @include_array = include.split(',').map!(&:strip)
    if @include_array.blank? || (@include_array - CannedResponseConstants::ALLOWED_INCLUDE_PARAMS).present?
      errors[:include] << :not_included
      (self.error_options ||= {}).merge!(include: { list: CannedResponseConstants::ALLOWED_INCLUDE_PARAMS.join(', ') })
    end
  end
end
