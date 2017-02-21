class ConversationValidation < ApiValidation
  CHECK_PARAMS_SET_FIELDS = %w(cloud_file_ids include_quoted_text).freeze

  attr_accessor :body, :full_text, :private, :user_id, :agent_id, :incoming, :notify_emails,
                :attachments, :to_emails, :cc_emails, :bcc_emails, :item, :from_email,
                :include_quoted_text, :include_original_attachments, :cloud_file_ids, 
                :cloud_files, :send_survey

  validates :body, data_type: { rules: String, required: true }, if: -> { !forward? }
  validates :body, data_type: { rules: String }, on: :forward
  validates :body, required: true, if: -> { include_quoted_text.to_s == 'false' || full_text.present? }, on: :forward
  validates :full_text, data_type: { rules: String }
  
  validates :user_id, :agent_id, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true, ignore_string: :allow_string_param }
  validates :private, :incoming, :include_quoted_text, :include_original_attachments, :send_survey, data_type: { rules: 'Boolean', ignore_string: :allow_string_param }
  validates :from_email, custom_format: { with: ApiConstants::EMAIL_VALIDATOR, allow_nil: true, accepted: :'valid email address' } 
  validates :notify_emails, :to_emails, :attachments, :cc_emails, :bcc_emails, data_type: { rules: Array }
  validates :notify_emails, :to_emails, :cc_emails, :bcc_emails, custom_length: { maximum: ApiTicketConstants::MAX_EMAIL_COUNT, message_options: { element_type: :values } }
  validates :notify_emails, :to_emails, :cc_emails, :bcc_emails, array: { custom_format: { with: ApiConstants::EMAIL_VALIDATOR, allow_nil: true, accepted: :'valid email address' } }
  validates :to_emails, required: true, on: :forward
  validates :include_quoted_text, custom_absence: { message: :cannot_be_set }, if: -> { include_quoted_text.to_s == 'true' && full_text.present? }

  validates :attachments, array: { data_type: { rules: ApiConstants::UPLOADED_FILE_TYPE, allow_nil: true } }
  validates :attachments, file_size: {
    max: ApiConstants::ALLOWED_ATTACHMENT_SIZE,
    base_size: proc { |x| ValidationHelper.attachment_size(x.item) }
  }
  validates :cloud_files, data_type: { rules: Array, allow_nil: false }
  validates :cloud_files, array: { data_type: { rules: Hash, allow_nil: false } }
  # TODO-EMBER : message to be altered
  validates :cloud_file_ids, custom_absence: { message: :included_original_attachments }, if: -> { include_original_attachments.to_s == 'true' }, on: :forward
  validates :cloud_file_ids, data_type: { rules: Array, allow_nil: false }, array: { custom_numericality: { only_integer: true, greater_than: 0, allow_nil: false, ignore_string: :allow_string_param } }

  validate :validate_cloud_files, if: -> { cloud_files.present? && errors[:cloud_files].blank? }
  validate :validate_full_text_length, if: -> { body.present? && full_text.present? }

  def initialize(request_params, item, allow_string_param = false)
    super(request_params, item, allow_string_param)
    @body = item.body_html if !request_params.key?(:body) && item
    @item = item
  end

  def attributes_to_be_stripped
    ConversationConstants::ATTRIBUTES_TO_BE_STRIPPED
  end

  def forward?
    [:forward].include?(validation_context)
  end

  def validate_cloud_files
    cloud_file_hash_errors = []
    cloud_files.each_with_index do |cloud_file, index|
      cloud_file_validator = CloudFileValidation.new(cloud_file, nil)
      cloud_file_hash_errors << cloud_file_validator.errors.full_messages unless cloud_file_validator.valid?
    end
    errors[:cloud_files] << :"is invalid" if cloud_file_hash_errors.present?
  end

  def validate_full_text_length
    errors[:full_text] << :shorter_full_text if full_text.length <= body.length
  end
end
