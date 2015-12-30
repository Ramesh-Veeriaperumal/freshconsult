class NoteValidation < ApiValidation
  attr_accessor :body, :body_html, :private, :user_id, :incoming, :notify_emails,
                :attachments, :cc_emails, :bcc_emails, :item

  validates :body, required: true, data_type: { rules: String }
  validates :body_html, data_type: { rules: String, allow_nil: true }
  validates :user_id, custom_numericality: { allow_nil: true, ignore_string: :allow_string_param }
  validates :private, :incoming, data_type: { rules: 'Boolean', ignore_string: :allow_string_param }
  validates :notify_emails, :attachments, :cc_emails, :bcc_emails, data_type: { rules: Array }
  validate  :max_email_count
  validates :notify_emails, :cc_emails, :bcc_emails, array: { format: { with: ApiConstants::EMAIL_VALIDATOR, allow_nil: true, message: 'not_a_valid_email' } }
  validates :attachments, array: { data_type: { rules: ApiConstants::UPLOADED_FILE_TYPE, allow_nil: true } }

  validates :attachments, file_size:  {
    min: nil, max: ApiConstants::ALLOWED_ATTACHMENT_SIZE,
    base_size: proc { |x| Helpers::TicketsValidationHelper.attachment_size(x.item) }
  }, if: -> { attachments }

  def initialize(request_params, item, allow_string_param = false)
    super(request_params, item, allow_string_param)
    @item = item
    @body = request_params[:body_html] if should_set_body?(request_params)
  end

  def should_set_body?(request_params)
    request_params[:body].nil? && request_params[:body_html].present?
  end

  def attributes_to_be_stripped
    NoteConstants::ATTRIBUTES_TO_BE_STRIPPED
  end

  def max_email_count
    NoteConstants::EMAIL_FIELDS.each do |field|
      array_elements = send(field)
      if array_elements && errors[field].blank? && array_elements.count > TicketConstants::MAX_EMAIL_COUNT
        errors[field] << :max_count_exceeded
        (self.error_options ||= {}).merge!(field => { max_count: "#{TicketConstants::MAX_EMAIL_COUNT}" })
      end
    end
  end
end
