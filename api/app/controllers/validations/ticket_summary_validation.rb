class TicketSummaryValidation < ApiValidation

  attr_accessor :body, :user_id, :attachments, :cloud_files, :item, :inline_attachment_ids

  validates :body, data_type: { rules: String}
  validates :user_id, custom_numericality: { only_integer: true, greater_than: 0,
                                             allow_nil: true, ignore_string: :allow_string_param }
  validates :attachments, data_type: { rules: Array }
  validates :attachments, array: { data_type: { rules: ApiConstants::UPLOADED_FILE_TYPE, allow_nil: true } }
  validates :attachments, file_size: {
    max: proc { |x| x.attachment_limit },
    base_size: proc { |x| ValidationHelper.attachment_size(x.item) }
  }
  validates :cloud_files, data_type: { rules: Array, allow_nil: false }
  validates :cloud_files, array: { data_type: { rules: Hash, allow_nil: false } }
  validate :validate_cloud_files, if: -> { cloud_files.present? && errors[:cloud_files].blank? }
  validates :inline_attachment_ids, data_type: { rules: Array }

  def initialize(request_params, item, allow_string_param = false)
    super(request_params, item, allow_string_param)
    @body = item.body_html if !request_params.key?(:body) && item
    @item = item
  end

  def validate_cloud_files
    cloud_file_hash_errors = []
    cloud_files.each_with_index do |cloud_file, index|
      cloud_file_validator = CloudFileValidation.new(cloud_file, nil)
      cloud_file_hash_errors << cloud_file_validator.errors.full_messages unless cloud_file_validator.valid?
    end
    errors[:cloud_files] << :"is invalid" if cloud_file_hash_errors.present?
  end

end