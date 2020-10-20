class ConversationValidation < ApiValidation
  CHECK_PARAMS_SET_FIELDS = %w(cloud_file_ids include_quoted_text).freeze

  attr_accessor :body, :full_text, :private, :user_id, :agent_id, :incoming, :notify_emails,
                :attachments, :to_emails, :cc_emails, :bcc_emails, :item, :from_email,
                :include_quoted_text, :include_original_attachments, :cloud_file_ids,
                :cloud_files, :send_survey, :last_note_id, :include_surveymonkey_link, :inline_attachment_ids,
                :ticket_source, :msg_type, :parent_note_id, :twitter, :reply_ticket_id

  validates :body, data_type: { rules: String, required: true }, if: -> { !forward? && attachment_ids.blank? && cloud_files.blank? && !facebook_ticket? }
  validates :body, data_type: { rules: String, required: true }, if: -> { !forward? && attachment_ids.blank? && cloud_files.blank? && facebook_ticket? && validation_context != :reply }
  validates :body, data_type: { rules: String }, on: :forward
  validates :body, required: true, if: -> { include_quoted_text.to_s == 'false' || full_text.present? }, on: :forward
  validates :full_text, data_type: { rules: String }

  validates :user_id, :agent_id, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true, ignore_string: :allow_string_param }
  validates :last_note_id, custom_numericality: { only_integer: true, greater_than: -1, allow_nil: true, ignore_string: :allow_string_param }
  validates :include_surveymonkey_link, data_type: { rules: Integer}, inclusion: { in: [0, 1] }, if: -> { include_surveymonkey_link.present? }
  validates :private, :incoming, :include_quoted_text, :include_original_attachments, :send_survey, data_type: { rules: 'Boolean', ignore_string: :allow_string_param }
  validates :from_email, custom_format: { with: proc { AccountConstants.email_validator }, allow_nil: true, accepted: :'valid email address' }
  validates :notify_emails, :to_emails, :attachments, :cc_emails, :bcc_emails, data_type: { rules: Array }
  validates :notify_emails, :to_emails, :cc_emails, :bcc_emails, custom_length: { maximum: ApiTicketConstants::MAX_EMAIL_COUNT, message_options: { element_type: :values } }
  validates :notify_emails, :to_emails, :cc_emails, :bcc_emails, array: { custom_format: { with: proc { AccountConstants.named_email_validator }, allow_nil: true, accepted: :'valid email address' } }
  validates :to_emails, required: true, on: :forward
  validates :to_emails, required: true, on: :reply_to_forward
  validates :include_quoted_text, custom_absence: { message: :cannot_be_set }, if: -> { include_quoted_text.to_s == 'true' && full_text.present? }
  validates :reply_ticket_id, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true, ignore_string: :allow_string_param }, on: :reply

  validates :attachments, array: { data_type: { rules: ApiConstants::UPLOADED_FILE_TYPE, allow_nil: true } }
  validates :attachments, file_size: {
    max: proc { |x| x.attachment_limit },
    base_size: proc { |x| ValidationHelper.attachment_size(x.item) }
  }
  validates :cloud_files, data_type: { rules: Array, allow_nil: false }
  validates :cloud_files, array: { data_type: { rules: Hash, allow_nil: false } }
  # TODO-EMBER : message to be altered
  validates :cloud_file_ids, custom_absence: { message: :included_original_attachments }, if: -> { include_original_attachments.to_s == 'true' }, on: :forward
  validates :cloud_file_ids, data_type: { rules: Array, allow_nil: false }, array: { custom_numericality: { only_integer: true, greater_than: 0, allow_nil: false, ignore_string: :allow_string_param } }

  validate :validate_cloud_files, if: -> { cloud_files.present? && errors[:cloud_files].blank? }
  validate :validate_full_text_length, if: -> { body.present? && full_text.present? }

  validates :inline_attachment_ids, data_type: { rules: Array }

  # Facebook reply validations
  validates :body, data_type: { rules: String }, if: -> { facebook_ticket? }, on: :reply
  validates :attachments, custom_length: { maximum: 1 }, if: -> { facebook_ticket? }, on: :reply
  validates :parent_note_id, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true, ignore_string: :allow_string_param }, if: -> { facebook_ticket? }, on: :reply
  validate :either_body_attachments, if: -> { facebook_ticket? }, on: :reply

  # Twitter reply validations
  validates :twitter, data_type: { rules: Hash },
                      hash: {
                        tweet_type: {
                          data_type: { rules: String },
                          custom_inclusion: { in: ApiConstants::TWITTER_REPLY_TYPES }
                        },
                        twitter_handle_id: {
                          custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true, ignore_string: :allow_string_param }
                        }
                      }, if: -> { twitter_ticket? }, on: :reply

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
    errors[:full_text] << :shorter_full_text if full_text.length < body.length
    errors[:full_text] << :invalid_full_text if full_text.length == body.length && full_text != body
  end

  def either_body_attachments
    if body.present? && attachments.present? && msg_type && msg_type == Facebook::Constants::FB_MSG_TYPES[0]
      errors[:attachments] << :can_have_only_one_field
      (self.error_options ||= {})[:attachments] = { list: 'body, attachments' }
    end
    errors[:body] << :missing_field if body.blank? && attachments.blank?
  end

  def facebook_ticket?
    Account.current.launched?(:facebook_public_api) && ticket_source.present? && (ticket_source == Helpdesk::Source::FACEBOOK)
  end

  def twitter_ticket?
    Account.current.launched?(:twitter_public_api) && ticket_source.present? && (ticket_source == Helpdesk::Source::TWITTER)
  end

  def social_ticket?
    ticket_source.present? && (facebook_ticket? || twitter_ticket?)
  end
end
