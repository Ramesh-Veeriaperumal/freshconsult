class TicketValidation < ApiValidation
  MANDATORY_FIELD_ARRAY = [:requester_id, :phone, :email, :twitter_id, :facebook_id].freeze
  MANDATORY_FIELD_STRING = MANDATORY_FIELD_ARRAY.join(', ').freeze
  CHECK_PARAMS_SET_FIELDS = (MANDATORY_FIELD_ARRAY.map(&:to_s) + %w(fr_due_by due_by)).freeze

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

  validates :requester_id, :email_config_id, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true, ignore_string: :allow_string_param, greater_than: 0  }

  validate :requester_detail_missing, if: :requester_id_mandatory?
  # validates :requester_id, required: { allow_nil: false, message: :fill_a_mandatory_field, message_options: { field_names: 'requester_id, phone, email, twitter_id, facebook_id' } }, if: :requester_id_mandatory? # No
  validates :name, required: { allow_nil: false, message: :phone_mandatory }, if: :name_required?  # No
  validates :name, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :description, data_type: { rules: String, required: true }
  validates :description_html, data_type: { rules: String, allow_nil: true }

  # Due by and First response due by validations
  # Both should not be present in params if status is closed or resolved
  validates :fr_due_by, custom_absence: { allow_nil: true, message: :cannot_set_due_by_fields }, if: :disallow_fr_due_by?
  validates :due_by, custom_absence: { allow_nil: true, message: :cannot_set_due_by_fields }, if: :disallow_due_by?
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
  validates :attachments, required: true, if: -> { request_params.key? :attachments } # for attachments empty array scenario
  validates :attachments, data_type: { rules: Array, allow_nil: true }, array: { data_type: { rules: ApiConstants::UPLOADED_FILE_TYPE, allow_nil: false } }
  validates :attachments, file_size:  {
    max: ApiConstants::ALLOWED_ATTACHMENT_SIZE,
    base_size: proc { |x| TicketsValidationHelper.attachment_size(x.item) } }

  # Email related validations
  validates :email, data_type: { rules: String, allow_nil: true }
  validates :email, custom_format: { with: ApiConstants::EMAIL_VALIDATOR, accepted: :"valid email address", allow_nil: true }
  validates :email, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :cc_emails, data_type: { rules: Array }, array: { custom_format: { with: ApiConstants::EMAIL_VALIDATOR, allow_nil: true, accepted: :"valid email address" } }

  validates :cc_emails, custom_length: { maximum: ApiTicketConstants::MAX_EMAIL_COUNT, message_options: { element_type: :values } }

  # Tags validations
  validates :tags, data_type: { rules: Array }, array: { data_type: { rules: String, allow_nil: true }, custom_length: { maximum: ApiConstants::TAG_MAX_LENGTH_STRING } }
  validates :tags, string_rejection: { excluded_chars: [','], allow_nil: true }

  # Custom fields validations
  validates :custom_fields, data_type: { rules: Hash }
  validates :custom_fields, custom_field: { custom_fields:
                              {
                                validatable_custom_fields: proc { |x| TicketsValidationHelper.custom_non_dropdown_fields(x) },
                                required_based_on_status: proc { |x| x.required_based_on_status? },
                                required_attribute: :required,
                                ignore_string: :allow_string_param
                              }
                           }
  validates :twitter_id, :phone, :name, data_type: { rules: String, allow_nil: true }
  validates :twitter_id, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :phone, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }

  def initialize(request_params, item, allow_string_param = false)
    @request_params = request_params
    super(request_params, item, allow_string_param)
    @description = request_params[:description_html] if should_set_description?(request_params)
    @fr_due_by ||= item.try(:frDueBy).try(:iso8601) if item
    @due_by ||= item.try(:due_by).try(:iso8601) if item
    @item = item
  end

  def requester_detail_missing
    field = MANDATORY_FIELD_ARRAY.detect { |x| instance_variable_defined?("@#{x}_set") }
    field ? error_options[field] = { code: :invalid_value } : field = :requester_id
    errors[field] = :fill_a_mandatory_field
    (error_options[field] ||= {}).merge!(field_names: MANDATORY_FIELD_STRING)
  end

  def should_set_description?(request_params)
    request_params[:description].nil? && request_params[:description_html].present?
  end

  def requester_id_mandatory? # requester_id is must if any one of email/twitter_id/fb_profile_id/phone is not given.
    MANDATORY_FIELD_ARRAY.all? { |x| send(x).blank? && errors[x].blank? }
  end

  def name_required? # Name mandatory if phone number of a non existent contact is given. so that the contact will get on ticket callbacks.
    email.blank? && twitter_id.blank? && facebook_id.blank? && phone.present? && requester_id.blank?
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
      status: { custom_inclusion: { in: proc { |x| x.status_ids }, ignore_string: :allow_string_param, detect_type: true } },
      priority: { custom_inclusion: { in: ApiTicketConstants::PRIORITIES, ignore_string: :allow_string_param, detect_type: true } },
      source: { custom_inclusion: { in: ApiTicketConstants::SOURCES, ignore_string: :allow_string_param, detect_type: true } },
      ticket_type: { custom_inclusion: { in: proc { TicketsValidationHelper.ticket_type_values } } },
      group: { custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param, greater_than: 0 } },
      agent: { custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param, greater_than: 0 } },
      product: { custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param, greater_than: 0 } },
      subject: { data_type: { rules: String }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING } }
    }
  end
end
