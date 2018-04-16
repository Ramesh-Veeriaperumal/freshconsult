class CustomerNoteValidation < ApiValidation
  attr_accessor :attachments, :item # :cloud_file_ids, :cloud_files

  # attachments
  validates :attachments, array: { data_type: { rules: ApiConstants::UPLOADED_FILE_TYPE, allow_nil: true } }
  validates :attachments, file_size: {
    max: ApiConstants::ALLOWED_ATTACHMENT_SIZE,
    base_size: proc { |x| ValidationHelper.attachment_size(x.item) }
  }
  # validates :cloud_files, data_type: { rules: Array, allow_nil: false }
  # validates :cloud_files, array: { data_type: { rules: Hash, allow_nil: false } }
  # validates :cloud_file_ids, data_type: { rules: Array, allow_nil: false }, array: { custom_numericality: { only_integer: true, greater_than: 0, allow_nil: false, ignore_string: :allow_string_param } }
  # validate :validate_cloud_files, if: -> { cloud_files.present? && errors[:cloud_files].blank? }

  def initialize(request_params, item, allow_string_param = false)
    super(request_params, item, allow_string_param)
    @item = item
  end

  # private
  #
  #   def validate_cloud_files
  #     cloud_file_hash_errors = []
  #     cloud_files.each_with_index do |cloud_file, index|
  #       cloud_file_validator = CloudFileValidation.new(cloud_file, nil)
  #       cloud_file_hash_errors << cloud_file_validator.errors.full_messages unless cloud_file_validator.valid?
  #     end
  #     errors[:cloud_files] << :"is invalid" if cloud_file_hash_errors.present?
  #   end
end
