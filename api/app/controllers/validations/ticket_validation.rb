class TicketValidation < ApiValidation
  attr_accessor :id, :cc_emails, :description, :description_html, :due_by, :email_config_id, :fr_due_by, :group_id, :priority, :email,
                :phone, :twitter_id, :facebook_id, :requester_id, :name, :responder_id, :source, :status, :subject, :type,
                :product_id, :tags, :custom_fields, :attachments, :request_params, :item

  validates :due_by, :fr_due_by, date_time: { allow_nil: true }

  validates :group_id, :requester_id, :responder_id, :product_id, :email_config_id, numericality: { allow_nil: true }

  validates :requester_id, required: { allow_nil: false, message: 'requester_id_mandatory' }, if: :requester_id_mandatory?
  validates :name, required: { allow_nil: false, message: 'phone_mandatory' }, length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long }, if: :name_required?

  validates :priority, custom_inclusion: { in: TicketConstants::PRIORITY_TOKEN_BY_KEY.keys }, allow_nil: true

  # proc is used as inclusion array is not constant
  validates :status, custom_inclusion: { in: proc { Helpers::TicketsValidationHelper.ticket_status_values } }, allow_nil: true
  validates :source, custom_inclusion: { in: TicketConstants::SOURCE_KEYS_BY_TOKEN.except(:twitter, :forum, :facebook, :outbound_email).values }, allow_nil: true
  validates :type, custom_inclusion: { in: proc { Helpers::TicketsValidationHelper.ticket_type_values } }, allow_nil: true
  validates :fr_due_by, :due_by, inclusion: { in: [nil], message: 'invalid_field' }, if: :disallow_due_by?

  validates :tags, :cc_emails, :attachments, data_type: { rules: Array }, allow_nil: true
  validates :custom_fields, data_type: { rules: Hash }, allow_nil: true
  validates :attachments, array: { data_type: { rules: ApiConstants::UPLOADED_FILE_TYPE, allow_nil: true } }
  validates :due_by, required: { message: 'due_by_validation' }, if: -> { fr_due_by }
  validates :fr_due_by, required: { message: 'fr_due_by_validation' }, if: -> { due_by }

  validates :attachments, file_size:  {
    min: nil, max: ApiConstants::ALLOWED_ATTACHMENT_SIZE,
    base_size: proc { |x| Helpers::TicketsValidationHelper.attachment_size(x.item) }
  }, if: -> { attachments && errors[:attachments].blank? }

  validates :email, format: { with: ApiConstants::EMAIL_REGEX, message: 'not_a_valid_email' }, length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long }, if: :email_required?
  validates :cc_emails, array: { format: { with: ApiConstants::EMAIL_REGEX, allow_nil: true, message: 'not_a_valid_email' } }
  validate :due_by_validation, if: -> { @due_by_set && errors[:due_by].blank? }
  validate :cc_emails_max_count, if: -> { cc_emails && errors[:cc_emails].blank? }
  validates :tags, array: { length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long } }

  validates :custom_fields, custom_field: { custom_fields:
                              {
                                validatable_custom_fields: proc { Helpers::TicketsValidationHelper.data_type_validatable_custom_fields },
                                required_based_on_status: proc { |x| x.required_based_on_status? },
                                required_attribute: :required
                              }
                           }, if: -> { errors[:custom_fields].blank? }
  validates :subject, :twitter_id, :phone, length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long }

  def initialize(request_params, item)
    @request_params = request_params
    @cc_emails = item.cc_email[:cc_emails] if item
    @fr_due_by = item.try(:frDueBy).try(:to_s) if item
    @type = item.try(:ticket_type) if item
    super(request_params, item)
    check_params_set(request_params, item)
    @item = item
  end

  def requester_id_mandatory? # requester_id is must if any one of email/twitter_id/fb_profile_id/phone is not given.
    email.blank? && twitter_id.blank? && phone.blank? && facebook_id.blank?
  end

  def name_required? # Name mandatory if phone number of a non existent contact is given. so that the contact will get on ticket callbacks.
    email.blank? && twitter_id.blank? && facebook_id.blank? && phone.present? && requester_id.blank?
  end

  def email_required? # Email required if twitter_id/fb_profile_id/phone/requester_id is blank.
    email.present? && twitter_id.blank? && facebook_id.blank? && phone.blank? && requester_id.blank?
  end

  def due_by_validation
    errors.add(:due_by, 'start_time_lt_now') if due_by < (@item.try(:created_at) || Time.zone.now)
  end

  def cc_emails_max_count
    if cc_emails.count > TicketConstants::MAX_EMAIL_COUNT
      errors.add(:cc_emails, 'max_count_exceeded')
      (self.error_options ||= {}).merge!(cc_emails: { max_count: "#{TicketConstants::MAX_EMAIL_COUNT}" })
    end
  end

  def required_based_on_status?
    Helpdesk::TicketStatus.status_keys_by_name(Account.current).select { |x| ['Closed', 'Resolved'].include?(x) }.values.include?(status.to_i)
  end

  # due_by and fr_due_by should not be allowed if status is closed or resolved for consistency with Web.
  def disallow_due_by?
    if [:due_by, :fr_due_by].any? { |c| request_params.key?(c) }
      Helpdesk::TicketStatus.status_keys_by_name(Account.current).select { |x| ['Closed', 'Resolved'].include?(x) }.values.include?(status.to_i)
    end
  end

  def attributes_to_be_stripped
    ApiTicketConstants::FIELDS_TO_BE_STRIPPED
  end
end
