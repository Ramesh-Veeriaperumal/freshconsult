class CannedResponseFilterValidation < ApiValidation
  attr_accessor :include, :include_array, :ticket_id, :search_string, :folder_id
  validates :include, data_type: { rules: String}
  validate :validate_include, if: -> { errors[:include].blank? && include }
  validates :ticket_id, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true, ignore_string: :allow_string_param }
  validates :search_string, data_type: { rules: String, required: true}, if: :search?
  validates :folder_id, custom_numericality: { only_integer: true, allow_nil: true, greater_than: 0, ignore_string: :allow_string_param }
  validate :folder_id_valid?, if: -> { folder_id.present? && search? }
  
  def validate_include
    @include_array = include.split(',').map!(&:strip)
    if @include_array.blank? || (@include_array - CannedResponseConstants::ALLOWED_INCLUDE_PARAMS).present?
      errors[:include] << :not_included
      (self.error_options ||= {}).merge!(include: { list: CannedResponseConstants::ALLOWED_INCLUDE_PARAMS.join(', ') })
    end
  end

  def folder_id_valid?
    if Account.current.canned_response_folders.find_by_id(folder_id.to_i).nil?
      errors[:folder_id] << :absent_in_db
      error_options[:folder_id] = { resource: 'folder_id', attribute: folder_id }
    end
  end

  private
    def search?
      [:search].include?(validation_context)
    end
end
