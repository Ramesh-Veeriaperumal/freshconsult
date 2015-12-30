class TicketValidation < ApiValidation
  attr_accessor :id, :cc_emails, :description, :description_html, :due_by, :email_config_id, :fr_due_by, :group, :priority, :email,
                :phone, :twitter_id, :facebook_id, :requester_id, :name, :agent, :source, :status, :subject, :ticket_type,
                :product, :tags, :custom_fields, :attachments, :request_params, :item, :status_ids, :ticket_fields

  alias_attribute :type, :ticket_type
  alias_attribute :product_id, :product
  alias_attribute :group_id, :group
  alias_attribute :responder_id, :agent

  # Default fields validation
  validates :source, :ticket_type, :status, :subject, :priority, :product, :agent, :group, default_field:
                              {
                                required_fields: proc { |x| x.required_default_fields },
                                field_validations: proc { |x| x.default_field_validations }
                              }

  validates :requester_id, :email_config_id, custom_numericality: { allow_nil: true, ignore_string: :allow_string_param  }

  validates :requester_id, required: { allow_nil: false, message: :requester_id_mandatory }, if: :requester_id_mandatory? # No
  validates :name, required: { allow_nil: false, message: :phone_mandatory }, length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long }, if: :name_required?  # No
  validates :description, required: true, data_type: { rules: String }
  validates :description_html, data_type: { rules: String, allow_nil: true }

  # Due by and First response due by validations
  # Both should not be present in params if status is closed or resolved
  validates :fr_due_by, custom_absence: { allow_nil: true, message: :incompatible_field }, if: :disallow_fr_due_by?
  validates :due_by, custom_absence: { allow_nil: true, message: :incompatible_field }, if: :disallow_due_by?
  # Either both should be present or both should be absent, cannot send one of them in params.
  validates :due_by, required: { message: :due_by_validation }, if: -> { fr_due_by && errors[:fr_due_by].blank? }
  validates :fr_due_by, required: { message: :fr_due_by_validation }, if: -> { due_by && errors[:due_by].blank? }
  # Both should be a valid datetime
  validates :due_by, :fr_due_by, date_time: { allow_nil: true }
  # Both should be greater than created_at
  validate :due_by_gt_created_at, if: -> { @due_by_set && due_by && errors[:due_by].blank? }
  validate :fr_due_gt_created_at, if: -> { @fr_due_by_set && fr_due_by && errors[:fr_due_by].blank? }
  # Due by should be greater than or equal to fr_due_by
  validate :due_by_gt_fr_due_by, if: -> { (@due_by_set || @fr_due_by_set) && due_by && fr_due_by && errors[:due_by].blank? && errors[:fr_due_by].blank? }
  # Attachment validations
  validates :attachments, presence: true, if: -> { request_params.key? :attachments } # for attachments empty array scenario
  validates :attachments, data_type: { rules: Array, allow_nil: true }, array: { data_type: { rules: ApiConstants::UPLOADED_FILE_TYPE, allow_nil: false } }
  validates :attachments, file_size:  {
    min: nil, max: ApiConstants::ALLOWED_ATTACHMENT_SIZE,
    base_size: proc { |x| Helpers::TicketsValidationHelper.attachment_size(x.item) }
  }, if: -> { attachments }

  # Email related validations
  validates :email, format: { with: ApiConstants::EMAIL_VALIDATOR, message: 'not_a_valid_email' }, length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long }, if: :email_required?
  validates :cc_emails, data_type: { rules: Array }, array: { format: { with: ApiConstants::EMAIL_VALIDATOR, allow_nil: true, message: 'not_a_valid_email' } }
  validate :cc_emails_max_count, if: -> { cc_emails && errors[:cc_emails].blank? }

  # Tags validations
  validates :tags, data_type: { rules: Array }, array: { data_type: { rules: String,  allow_nil: true }, length: { maximum: ApiConstants::TAG_MAX_LENGTH_STRING, message: :too_long,  allow_nil: true } }
  validates :tags, string_rejection: { excluded_chars: [','] }

  # Custom fields validations
  validates :custom_fields, data_type: { rules: Hash }
  validates :custom_fields, custom_field: { custom_fields:
                              {
                                validatable_custom_fields: proc { |x| Helpers::TicketsValidationHelper.custom_non_dropdown_fields(x) },
                                required_based_on_status: proc { |x| x.required_based_on_status? },
                                required_attribute: :required,
                                ignore_string: :allow_string_param
                              }
                           }
  validates :twitter_id, :phone, length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long }

  def initialize(request_params, item, allow_string_param = false)
    @request_params = request_params
    super(request_params, item, allow_string_param)
    @description = request_params[:description_html] if should_set_description?(request_params)
    check_params_set(request_params, item)
    @fr_due_by ||= item.try(:frDueBy).try(:iso8601) if item
    @due_by ||= item.try(:due_by).try(:iso8601) if item
    @item = item
  end

  def should_set_description?(request_params)
    request_params[:description].nil? && request_params[:description_html].present?
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

  def due_by_gt_created_at
    errors[:due_by] << :gt_created_and_now if due_by < (@item.try(:created_at) || Time.zone.now)
  end

  def fr_due_gt_created_at
    errors[:fr_due_by] << :gt_created_and_now if fr_due_by < (@item.try(:created_at) || Time.zone.now)
  end

  def due_by_gt_fr_due_by
    # Due By is parsed here as if both values are given as input string comparison would be done instead of Date Comparison.
    parsed_due_by = DateTime.parse(due_by)
    if fr_due_by > parsed_due_by
      att = @fr_due_by_set ? :fr_due_by : :due_by
      errors[att] << :lt_due_by
    end
  end

  def cc_emails_max_count
    if cc_emails.count > TicketConstants::MAX_EMAIL_COUNT
      errors[:cc_emails] << :max_count_exceeded
      (self.error_options ||= {}).merge!(cc_emails: { max_count: "#{TicketConstants::MAX_EMAIL_COUNT}" })
    end
  end

  def required_based_on_status?
    status.respond_to?(:to_i) && [ApiTicketConstants::CLOSED, ApiTicketConstants::RESOLVED].include?(status.to_i)
  end

  # due_by and fr_due_by should not be allowed if status is closed or resolved for consistency with Web.
  def disallow_due_by?
    request_params[:due_by] && disallowed_status?
  end

  def disallow_fr_due_by?
    request_params[:fr_due_by] && disallowed_status?
  end

  def disallowed_status?
    errors[:status].blank? && [ApiTicketConstants::CLOSED, ApiTicketConstants::RESOLVED].include?(status.to_i)
  end

  def attributes_to_be_stripped
    ApiTicketConstants::ATTRIBUTES_TO_BE_STRIPPED
  end

  def required_default_fields
    closure_status = required_based_on_status?
    ticket_fields.select { |x| x.default && (x.required || (x.required_for_closure && closure_status)) }
  end

  def default_field_validations
    {
      status: { custom_inclusion: { in: proc { |x| x.status_ids }, ignore_string: :allow_string_param } },
      priority: { custom_inclusion: { in: ApiTicketConstants::PRIORITIES, ignore_string: :allow_string_param } },
      source: { custom_inclusion: { in: ApiTicketConstants::SOURCES, ignore_string: :allow_string_param } },
      ticket_type: { custom_inclusion: { in: proc { Helpers::TicketsValidationHelper.ticket_type_values } } },
      group: { custom_numericality: { ignore_string: :allow_string_param } },
      agent: { custom_numericality: { ignore_string: :allow_string_param } },
      product: { custom_numericality: { ignore_string: :allow_string_param } },
      subject: { length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long } }
    }
  end
end
