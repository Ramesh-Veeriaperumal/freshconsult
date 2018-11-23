class CustomerImportFilterValidation < FilterValidation
  include CustomerImportConstants

  attr_accessor :status
  validates :status, data_type: { rules: String }
  validate :validate_status, if: -> { errors[:status].blank? && status.present? }

  def validate_status
    @status_array = status.split(',').map!(&:strip)
    unless @status_array.present? && (@status_array - ALLOWED_STATUS_PARAMS).blank?
      errors[:status] << :not_included
      (self.error_options ||= {}).merge!(status: { list: ALLOWED_STATUS_PARAMS.join(', ') })
    end
  end
end
